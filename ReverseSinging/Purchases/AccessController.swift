//
//  AccessController.swift
//  ReverseSinging
//
//  The one answer to "can this person use the app right now", and the only place
//  that talks to RevenueCat.
//

import Combine
import Foundation
import RevenueCat
import DubloonFoundation

/// Why the app is open to someone who has not bought it.
nonisolated enum UnlockReason: Equatable {
    /// They own the entitlement.
    case entitlement
    /// They were using the app before it started charging, so they never will.
    /// See `EarlyAdopter`.
    case earlyAdopter
    /// Gating is off for this build or this run: no API key, or a screenshot run.
    /// Access is full, but there is still something to sell, so the upgrade offer
    /// stays visible.
    case gatingDisabled
}

/// What the app is allowed to do right now.
nonisolated enum AccessState: Equatable {
    case unlocked(UnlockReason)
    /// Nothing was bought. The paid games are padlocked on the menu and open the
    /// paywall instead of themselves; the free ones play as they always do.
    case locked
}

/// Owns the store session and turns it into one `AccessState`.
///
/// A singleton because `Purchases` is one too, and because who has paid has to be
/// decided in exactly one place: two views disagreeing about it is the failure mode
/// that gets refunds requested.
///
/// **The rule is fixed, and it is short.** Someone who owns Dubloon Pro has
/// everything. So does an early adopter. Everyone else is `locked` from the first
/// launch: there is no free window, and nothing outside the binary can change that.
/// What `locked` costs them is decided on the menu (`HomeViewModel`), where reverse
/// singing and Home Video Dub stay free.
///
/// Nothing waits on the network to say so. A purchase is remembered on the device,
/// so someone who has paid is never shown a padlock on the way in, online or off;
/// and a new install that turns out to belong to a buyer unlocks as soon as the
/// store has been heard from, without a tap on Restore.
@MainActor
final class AccessController: ObservableObject {

    static let shared = AccessController()

    // MARK: - Published

    @Published private(set) var state: AccessState = .locked

    /// The last customer info seen, for the settings screen and for anything that
    /// wants purchase dates or the management URL.
    @Published private(set) var customerInfo: CustomerInfo?

    /// Set when a restore or a purchase fails in a way worth telling the user
    /// about. Cleared by the UI once shown.
    @Published var errorMessage: String?

    /// Set after a restore that found nothing, so the UI can say so rather than
    /// silently doing nothing.
    @Published var restoreFoundNothing = false

    @Published private(set) var isRestoring = false

    @Published private(set) var isPurchasing = false

    // MARK: - Derived

    /// They have paid.
    var isPro: Bool { state == .unlocked(.entitlement) }

    /// They pay for it by subscription rather than having bought it outright. The lifetime
    /// purchase grants an entitlement with no expiry date; every subscription has one.
    var isSubscriber: Bool {
        isPro && entitlement?.expirationDate != nil
    }

    /// The Pro entitlement as last reported, active or not.
    var entitlement: EntitlementInfo? {
        customerInfo?.entitlements[PurchaseConfiguration.entitlementID]
    }

    /// The earliest date this person is known to have had the app, for the About screen.
    ///
    /// Apple's download date follows the account across reinstalls, so it is usually the
    /// oldest; RevenueCat's first sighting and the app's own first launch stand in when the
    /// receipt has not reported one. For an early adopter recognised from local traces the
    /// first launch is that of the build carrying the paywall, so this can be later than the
    /// day they really arrived — never earlier.
    var memberSince: Date? {
        [storeDownloadDate, customerInfo?.firstSeen, firstLaunch.date].compactMap { $0 }.min()
    }

    /// They were here before the paywall and are exempt from it for good.
    var isEarlyAdopter: Bool { state == .unlocked(.earlyAdopter) }

    /// The paid games must not be playable until something is bought.
    var isLocked: Bool { state == .locked }

    /// Whether there is still something to sell this person. An early adopter
    /// already has everything, so there is not.
    var canUpgrade: Bool { !isPro && !isEarlyAdopter }

    /// Whether to show the "welcome to the club" note. Shown once.
    var shouldWelcomeEarlyAdopter: Bool {
        isEarlyAdopter && !earlyAdopter.hasSeenWelcome
    }

    func markEarlyAdopterWelcomed() {
        earlyAdopter.markWelcomeSeen()
        objectWillChange.send()
    }

    // MARK: - Private

    private let firstLaunch = FirstLaunchDate()
    private let earlyAdopter: EarlyAdopter
    private var streamTask: Task<Void, Never>?
    private var isConfigured = false

    /// Entitlement as last reported.
    private var hasEntitlement = false

    /// False until the first customer info lands, from the SDK's cache or the store.
    private var hasCustomerInfo = false

    /// One silent receipt sync per foreground. See `syncReceiptIfNeverPosted()`.
    private var hasRequestedReceiptSync = false

    private init(earlyAdopter: EarlyAdopter = .shared) {
        self.earlyAdopter = earlyAdopter
    }

    // MARK: - Start

    /// Configures the SDK and starts listening. Called once, at launch.
    func start() {
        guard !isConfigured else { return }
        isConfigured = true

        #if DEBUG
        // A screenshot run is not a customer, and it must never meet a paywall.
        if ScreenshotMode.isActive {
            state = .unlocked(.gatingDisabled)
            return
        }
        if let forced = DebugAccessOverride.state {
            state = forced
        }
        #endif

        firstLaunch.record()

        // Before anything else this launch writes: the traces it reads are the
        // ones the app left in earlier versions, and the first screen overwrites
        // some of them.
        earlyAdopter.resolveFromLocalUsage()

        guard let apiKey = PurchaseConfiguration.apiKey else {
            // A release build with no key. Nothing can be sold, so nothing is
            // gated — but this is a shipping mistake, so it is reported.
            CrashReporter.shared.recordFailure(
                "purchases_not_configured",
                reason: "No RevenueCat API key for this build configuration"
            )
            state = .unlocked(.gatingDisabled)
            return
        }

        Purchases.logLevel = {
            #if DEBUG
            return .debug
            #else
            return .error
            #endif
        }()

        // No `appUserID`: the app has no accounts, so RevenueCat's anonymous ID is
        // the right identity. A purchase still restores across devices through the
        // Apple Account, which is what `restore()` asks for.
        Purchases.configure(with: Configuration.Builder(withAPIKey: apiKey).build())

        // What the SDK remembers from the last launch, read before the first frame:
        // someone who has paid opens onto an unlocked menu, with or without a network.
        if let cached = Purchases.shared.cachedCustomerInfo {
            apply(cached)
        } else {
            recompute()
        }

        observeCustomerInfo()
        Task { await refresh() }
    }

    /// Streams entitlement changes for the life of the app.
    ///
    /// The stream fires on renewals, expirations, restores and purchases made
    /// anywhere — including a purchase completed inside RevenueCat's own paywall,
    /// which is why the paywall's completion handler does not have to be the thing
    /// that unlocks the app.
    private func observeCustomerInfo() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard Purchases.isConfigured else { return }
            for await info in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                self?.apply(info)
            }
        }
    }

    // MARK: - Reading

    /// Asks the store for the current entitlement.
    ///
    /// Cheap to call: the SDK serves a cached answer and refreshes behind it. Worth
    /// calling on foreground so a purchase made on another device shows up.
    func refresh() async {
        guard Purchases.isConfigured else { return }
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            // The cached entitlement stays in force. Only report it if we have
            // never had one, since a failure to refresh a known-good answer is noise.
            if !hasCustomerInfo {
                CrashReporter.shared.record(error, context: "customer_info_fetch")
            }
        }
    }

    /// Called on every foreground so a purchase made on another device, or a
    /// subscription that lapsed overnight, is noticed.
    func refreshOnForeground() {
        hasRequestedReceiptSync = false
        recompute()
        Task { await refresh() }
    }

    /// The start of the day version 1.0.0 was created in App Store Connect (2025-10-26 UTC).
    /// Nobody downloaded the app before it.
    nonisolated static let storeDebut = Date(timeIntervalSince1970: 1_761_436_800)

    /// The store's download date, or nil when it cannot be a real one. Sandbox and
    /// TestFlight receipts report every download as 2013-08-01, twelve years before the
    /// app existed, and "Member since 2013" is not something to print.
    nonisolated static func plausibleDownloadDate(_ date: Date?) -> Date? {
        guard let date, date >= storeDebut else { return nil }
        return date
    }

    private var storeDownloadDate: Date? {
        Self.plausibleDownloadDate(customerInfo?.originalPurchaseDate)
    }

    private func apply(_ info: CustomerInfo) {
        customerInfo = info
        hasCustomerInfo = true
        hasEntitlement = info.entitlements[PurchaseConfiguration.entitlementID]?.isActive == true
        recompute()
    }

    // MARK: - Deciding

    /// The whole rule, in one place.
    private func recompute() {
        #if DEBUG
        if ScreenshotMode.isActive {
            state = .unlocked(.gatingDisabled)
            return
        }
        if let forced = DebugAccessOverride.state {
            set(forced)
            return
        }
        #endif

        if hasEntitlement {
            set(.unlocked(.entitlement))
            return
        }

        // Decided from traces on the device, so it needs no network: an early
        // adopter never sees a padlock, even offline.
        if earlyAdopter.isEarlyAdopter {
            set(.unlocked(.earlyAdopter))
            return
        }

        guard PurchaseConfiguration.apiKey != nil else {
            set(.unlocked(.gatingDisabled))
            return
        }

        set(.locked)
        syncReceiptIfNeverPosted()
    }

    /// Hands the store this install's receipt, once, so a purchase made before a
    /// reinstall or on another device comes back by itself.
    ///
    /// RevenueCat only knows what an Apple Account owns once a receipt has been
    /// posted, and nothing posts one for a fresh install. Without this, someone who
    /// bought Dubloon Pro and then changed phone would meet padlocks until they
    /// found Restore. `syncPurchases` posts it without the App Store sign-in prompt
    /// that a restore can raise, so it is safe to do unasked.
    ///
    /// Only while the store has no download date for this install, which is how a
    /// receipt that was never posted looks, and once per foreground rather than once
    /// per `recompute`: the answer arrives through `apply`, which recomputes, and a
    /// store that still has nothing must not turn that into a loop.
    private func syncReceiptIfNeverPosted() {
        guard Purchases.isConfigured, hasCustomerInfo, !hasRequestedReceiptSync,
              customerInfo?.originalPurchaseDate == nil else { return }
        hasRequestedReceiptSync = true

        Task { [weak self] in
            do {
                self?.apply(try await Purchases.shared.syncPurchases())
            } catch {
                CrashReporter.shared.record(error, context: "receipt_sync")
            }
        }
    }

    private func set(_ newState: AccessState) {
        guard newState != state else { return }
        state = newState

        if newState == .unlocked(.entitlement) {
            CrashReporter.shared.log("pro_unlocked")
        }
    }

    // MARK: - Buying

    /// Brings a purchase back on a new device or after a reinstall.
    ///
    /// The App Store requires this to exist and to be reachable without paying,
    /// which is why it is on the paywall as well as in settings.
    func restore() async {
        guard Purchases.isConfigured, !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            restoreFoundNothing = !isPro
            AnalyticsManager.shared.trackRestoreCompleted(foundEntitlement: isPro)
        } catch {
            errorMessage = Self.message(for: error)
            CrashReporter.shared.record(error, context: "restore_purchases")
            AnalyticsManager.shared.trackRestoreFailed(reason: Self.reason(for: error))
        }
    }

    /// Buys a product directly. The fallback paywall uses this when there is no offering to
    /// buy from; the dashboard paywall does its own buying.
    func purchase(_ product: StoreProduct) async {
        await runPurchase(productID: product.productIdentifier, source: "fallback_paywall") {
            try await Purchases.shared.purchase(product: product)
        }
    }

    /// Buys a package from an offering: the Mac's paywall. Buying the package rather than its
    /// product tells RevenueCat which offering was on screen, which is what attributes the
    /// purchase to the experiment arm that sold it.
    func purchase(_ package: Package, source: String) async {
        await runPurchase(productID: package.storeProduct.productIdentifier, source: source) {
            try await Purchases.shared.purchase(package: package)
        }
    }

    private func runPurchase(
        productID: String,
        source: String,
        _ buy: () async throws -> PurchaseResultData
    ) async {
        guard Purchases.isConfigured, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await buy()
            guard !result.userCancelled else { return }
            apply(result.customerInfo)
            AnalyticsManager.shared.trackPurchaseCompleted(productID: productID, source: source)
        } catch {
            // A cancel is a decision, not a failure, and gets no alert.
            guard !Self.isCancellation(error) else { return }
            errorMessage = Self.message(for: error)
            Self.reportPurchaseFailure(error, context: "purchase")
        }
    }

    /// The paywall UI finished a purchase or a restore. The stream will report the
    /// same thing a moment later; applying it here just removes the lag.
    func handleCompletion(_ info: CustomerInfo) {
        apply(info)
    }

    // MARK: - Errors

    /// What to show the user.
    ///
    /// RevenueCat's own descriptions are written for people, are localized by the
    /// SDK, and say more than a generic apology would, so they are preferred where
    /// they exist.
    private static func message(for error: Error) -> String {
        let description = (error as NSError).localizedDescription
        return description.isEmpty ? Strings.Pro.errorGeneric : description
    }

    /// Whether the user backed out of the App Store sheet.
    ///
    /// The SDK throws its errors as `NSError` in its own domain, so the code is
    /// compared rather than the type: `error as? ErrorCode` does not match what
    /// `purchase(package:)` actually throws.
    private static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == RevenueCat.ErrorCode.errorDomain
            && error.code == RevenueCat.ErrorCode.purchaseCancelledError.rawValue
    }

    /// Records a failed purchase, in analytics always and in Crashlytics only when the app
    /// might be to blame.
    ///
    /// A payment waiting on a parent or a bank, a device whose Screen Time forbids buying, and
    /// an App Store that is down were three of the paywall's top non-fatals, and not one of
    /// them is anything this app can fix.
    static func reportPurchaseFailure(_ error: Error, context: String) {
        AnalyticsManager.shared.trackPurchaseFailed(reason: reason(for: error))
        if isStoreOutcome(error) {
            CrashReporter.shared.log("\(context): \(reason(for: error))")
        } else {
            CrashReporter.shared.record(error, context: context)
        }
    }

    private static func isStoreOutcome(_ error: Error) -> Bool {
        let error = error as NSError
        guard error.domain == RevenueCat.ErrorCode.errorDomain else { return false }
        return [
            RevenueCat.ErrorCode.paymentPendingError,
            .purchaseNotAllowedError,
            .storeProblemError
        ].map(\.rawValue).contains(error.code)
    }

    /// A short, stable string for analytics — never the localized message, which
    /// would split one failure across seven languages.
    private static func reason(for error: Error) -> String {
        let error = error as NSError
        return error.domain == RevenueCat.ErrorCode.errorDomain
            ? "rc_\(error.code)"
            : "\(error.domain)_\(error.code)"
    }

    // MARK: - Testing

    #if DEBUG
    /// Drops the app into a given state so the locked menu and the paywall can be
    /// looked at, or tested, without a store.
    func overrideStateForTesting(_ newState: AccessState) {
        state = newState
    }
    #endif
}

#if DEBUG
/// A launch argument that holds a debug build in one state whatever the store says:
/// `-forceAccessState locked` or `-forceAccessState unlocked`.
nonisolated enum DebugAccessOverride {

    static var state: AccessState? {
        switch UserDefaults.standard.string(forKey: "forceAccessState") {
        case "locked": .locked
        case "unlocked": .unlocked(.entitlement)
        default: nil
        }
    }
}
#endif
