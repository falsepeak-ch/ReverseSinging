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
    /// Gating is off for this build or this device: no API key, the Remote Config
    /// kill switch, or a screenshot run. Access is full, but there is still
    /// something to sell, so the upgrade offer stays visible.
    case gatingDisabled
}

/// What the app is allowed to do right now.
nonisolated enum AccessState: Equatable {
    /// Not enough is known to gate anyone: the first customer info has not
    /// arrived, or the download date or the console's cutoff is still missing (see
    /// `PaywallEligibility`). The app is usable and shows no trial and no paywall —
    /// a cold launch must not flash one while the network is still being asked,
    /// and nobody is gated on a guess.
    case unknown
    case unlocked(UnlockReason)
    /// Inside the free window.
    case trial(daysRemaining: Int, endsAt: Date)
    /// The free window closed and nothing was bought. How that is put in front of
    /// the user is `LockPresentation`'s call, not this one's.
    case locked
}

/// How a closed free window meets the user.
///
/// Separate from `AccessState` because it is not a fact about the person, only
/// about how insistent the app is being with them, and the console can change
/// that without anything about their access changing.
nonisolated enum LockPresentation: Equatable {
    /// Nothing is locked.
    case none
    /// The menu stays open and says the trial is over; both games on it are
    /// disabled, and they or the note open a paywall that can be closed again.
    case soft
    /// The paywall covers the whole app and cannot be closed.
    case hard

    init(state: AccessState, isHardPaywallEnabled: Bool) {
        guard state == .locked else {
            self = .none
            return
        }
        self = isHardPaywallEnabled ? .hard : .soft
    }
}

/// Owns the store session and turns it, plus the trial clock, into one `AccessState`.
///
/// A singleton because `Purchases` is one too, and because the hard paywall has to
/// be decided in exactly one place: two views disagreeing about whether someone has
/// paid is the failure mode that gets refunds requested.
///
/// **It fails open.** Every path that cannot get a straight answer — no API key, a
/// store that will not load, a Remote Config fetch that never lands — leaves the
/// app usable. A paywall that wrongly locks a paying user out costs more than a
/// paywall that wrongly lets a free one in.
@MainActor
final class AccessController: ObservableObject {

    static let shared = AccessController()

    // MARK: - Published

    @Published private(set) var state: AccessState = .unknown

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
        isPro && customerInfo?.entitlements[PurchaseConfiguration.entitlementID]?.expirationDate != nil
    }

    /// They were here before the paywall and are exempt from it for good.
    var isEarlyAdopter: Bool { state == .unlocked(.earlyAdopter) }

    /// The games must not be playable until something is bought.
    var isLocked: Bool { state == .locked }

    /// Whether being locked covers the app or only disables the games.
    var lockPresentation: LockPresentation {
        var isHardPaywallEnabled = remoteConfig.isHardPaywallEnabled
        #if DEBUG
        isHardPaywallEnabled = DebugAccessOverride.isHardPaywallEnabled ?? isHardPaywallEnabled
        #endif
        return LockPresentation(state: state, isHardPaywallEnabled: isHardPaywallEnabled)
    }

    /// Days left, or nil outside the trial. Drives the counter.
    var trialDaysRemaining: Int? {
        if case .trial(let days, _) = state { return days }
        return nil
    }

    /// Whether the console gives new users a free window at all. With a length of zero the
    /// lock arrives on first launch, and nothing may say a trial has ended.
    var hasTrial: Bool { remoteConfig.trialLengthInDays > 0 }

    /// Whether there is still something to sell this person. An early adopter
    /// already has everything, so there is not.
    var canUpgrade: Bool { !isPro && !isEarlyAdopter }

    /// Whether to show the "welcome to the club" note. Shown once, and only once
    /// the paywall is actually live: announcing an exemption from a wall nobody
    /// has met yet would raise a question rather than answer one.
    var shouldWelcomeEarlyAdopter: Bool {
        isEarlyAdopter && remoteConfig.isPaywallEnabled && !earlyAdopter.hasSeenWelcome
    }

    func markEarlyAdopterWelcomed() {
        earlyAdopter.markWelcomeSeen()
        objectWillChange.send()
    }

    // MARK: - Private

    private let trialClock: TrialClock
    private let firstLaunch = FirstLaunchDate()
    private let earlyAdopter: EarlyAdopter
    private let remoteConfig: RemoteConfigService
    private var streamTask: Task<Void, Never>?
    private var configCancellable: AnyCancellable?
    private var isConfigured = false

    /// Entitlement as last reported. Kept separately from `state` so a Remote
    /// Config change or a day rolling over can recompute without re-asking the store.
    private var hasEntitlement = false

    /// Nil until the first customer info lands; `unknown` holds until then.
    private var hasCustomerInfo = false

    /// One silent receipt sync per foreground, for the download date. See
    /// `syncReceiptForDownloadDate()`.
    private var hasRequestedReceiptSync = false

    /// Whether this launch's sync has come back, with or without a date. Until it
    /// has, the first-launch fallback stays out of it: the store is about to
    /// answer, and its answer is the better one.
    private var hasReceiptSyncSettled = false

    private var hasReportedMissingDownloadDate = false

    /// Remembered across launches: the store was reached and had no download date
    /// for this account. Lets the fallback apply from the first frame of the next
    /// launch instead of after a second of looking unlocked. Cleared the moment a
    /// date does turn up.
    private static let storeHadNoDownloadDateKey = "downloadDate.storeHadNone"
    private var storeHadNoDownloadDate: Bool {
        get { UserDefaults.standard.bool(forKey: Self.storeHadNoDownloadDateKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.storeHadNoDownloadDateKey) }
    }

    private init(
        trialClock: TrialClock = TrialClock(),
        earlyAdopter: EarlyAdopter = .shared,
        remoteConfig: RemoteConfigService = .shared
    ) {
        self.trialClock = trialClock
        self.earlyAdopter = earlyAdopter
        self.remoteConfig = remoteConfig
    }

    // MARK: - Start

    /// Configures the SDK and starts listening. Called once, at launch.
    func start() {
        guard !isConfigured else { return }
        isConfigured = true

        #if DEBUG
        // A screenshot run is not a customer. It also has no Firebase, so there is
        // no Remote Config to ask, and it must never meet a paywall.
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

        // Recompute whenever the console changes the length or throws the switch.
        configCancellable = remoteConfig.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    // Not every knob moves `state`: how a lock is presented does
                    // not, so whoever reads it is told by hand.
                    self.objectWillChange.send()
                    self.recompute()
                }
            }

        Task { await remoteConfig.start() }

        guard let apiKey = PurchaseConfiguration.apiKey else {
            // A release build with no key. Nothing to check against, so nothing is
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

    /// Called on every foreground so a trial that ran out overnight is noticed.
    func refreshOnForeground() {
        hasRequestedReceiptSync = false
        recompute()
        Task { await refresh() }
    }

    /// Apple's download date, minus the sandbox's placeholder. See
    /// `PaywallEligibility.plausibleDownloadDate`.
    private var storeDownloadDate: Date? {
        PaywallEligibility.plausibleDownloadDate(customerInfo?.originalPurchaseDate)
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

        // A reinstall or a new phone loses the local traces; the receipt does not.
        // Here rather than in `apply` because it depends on two things that arrive
        // separately and in either order — the customer info and the Remote Config
        // cutoff — and this runs when either of them lands.
        earlyAdopter.considerOriginalPurchaseDate(
            storeDownloadDate, before: remoteConfig.paywallReleaseDate
        )

        // Ahead of the kill switch and the trial both, and not conditional on the
        // store having answered: an exemption decided from local traces needs no
        // network, so an early adopter never sees a paywall even offline.
        if earlyAdopter.isEarlyAdopter {
            set(.unlocked(.earlyAdopter))
            return
        }

        guard PurchaseConfiguration.apiKey != nil, remoteConfig.isPaywallEnabled else {
            set(.unlocked(.gatingDisabled))
            return
        }

        // Hold at `unknown` until the store has answered once. Locking someone out
        // on the strength of "we have not asked yet" is the one unrecoverable
        // mistake this class can make.
        guard hasCustomerInfo else {
            set(.unknown)
            return
        }

        // The trial and the paywall are for people who downloaded the app on or
        // after the console's date, and for nobody else. Apple's date decides it
        // when there is one. When the store has been asked and has none, the app's
        // own first-launch date stands in — see `PaywallEligibility` for how far.
        let downloadedAt = storeDownloadDate
        if downloadedAt == nil {
            syncReceiptForDownloadDate()
        } else {
            storeHadNoDownloadDate = false
        }

        let mayFallBack = hasReceiptSyncSettled || storeHadNoDownloadDate
        let eligibility = PaywallEligibility(
            downloadedAt: downloadedAt,
            firstLaunchedAt: mayFallBack ? firstLaunch.date : nil,
            cutoff: remoteConfig.paywallReleaseDate
        )
        if downloadedAt == nil, mayFallBack {
            reportMissingDownloadDate(fallbackOutcome: eligibility)
        }

        guard eligibility == .eligible else {
            // `.exempt` cannot reach here — it was granted above and returned — so
            // this is `.undetermined`.
            set(.unknown)
            return
        }

        switch trialClock.state(lengthInDays: remoteConfig.trialLengthInDays) {
        case .active(let daysRemaining, let endsAt):
            set(.trial(daysRemaining: daysRemaining, endsAt: endsAt))
        case .expired:
            set(.locked)
        }
    }

    /// Tells Crashlytics that this user is being decided without Apple's date.
    ///
    /// Counted because how often it happens is how much of the gate rests on the
    /// fallback, and `fallback_outcome` says which way it went: `eligible` is a
    /// user gated on the first-launch date alone, `undetermined` is one who is not
    /// gated at all. Once per launch: `recompute` runs many times, and a user in
    /// this state re-syncs on every foreground, so anything more would count
    /// foregrounds rather than people.
    private func reportMissingDownloadDate(fallbackOutcome: PaywallEligibility) {
        guard !hasReportedMissingDownloadDate else { return }
        hasReportedMissingDownloadDate = true

        CrashReporter.shared.recordFailure(
            "download_date_unavailable",
            reason: "No originalPurchaseDate; deciding from the first-launch date",
            keys: [
                "fallback_outcome": fallbackOutcome == .eligible ? "eligible" : "undetermined",
                // False when the sync itself failed, so a store outage can be told
                // apart from a store that simply has no date for this account.
                "store_reached": storeHadNoDownloadDate
            ]
        )
    }

    /// Asks the store to report the receipt, which is where the download date is.
    ///
    /// RevenueCat only learns `originalPurchaseDate` once a receipt has been posted,
    /// and nothing posts one for someone who has never bought or restored — which
    /// is every new user, and every early adopter on a new phone. `syncPurchases`
    /// posts it without the App Store sign-in prompt that a restore can raise, so
    /// it is safe to do unasked.
    ///
    /// Once per foreground rather than once per `recompute`: the answer arrives
    /// through `apply`, which recomputes, and a store that still has no date must
    /// not turn that into a loop.
    private func syncReceiptForDownloadDate() {
        guard Purchases.isConfigured, !hasRequestedReceiptSync else { return }
        hasRequestedReceiptSync = true

        Task { [weak self] in
            do {
                let info = try await Purchases.shared.syncPurchases()
                if PaywallEligibility.plausibleDownloadDate(info.originalPurchaseDate) == nil {
                    // Reachable, and still no date, so the first-launch date is
                    // what decides from here.
                    self?.storeHadNoDownloadDate = true
                }
                self?.hasReceiptSyncSettled = true
                self?.apply(info)
            } catch {
                // Not remembered across launches: this says the store could not be
                // reached, not that it has no date.
                CrashReporter.shared.record(error, context: "receipt_sync_download_date")
                self?.hasReceiptSyncSettled = true
                self?.recompute()
            }
        }
    }

    private func set(_ newState: AccessState) {
        guard newState != state else { return }
        let previous = state
        state = newState

        switch newState {
        case .locked where previous != .locked:
            AnalyticsManager.shared.trackTrialExpired(
                trialLengthInDays: remoteConfig.trialLengthInDays
            )
        case .unlocked(.entitlement) where previous != .unlocked(.entitlement):
            CrashReporter.shared.log("pro_unlocked")
        default:
            break
        }
    }

    // MARK: - Buying

    /// Brings a purchase back on a new device or after a reinstall.
    ///
    /// The App Store requires this to exist and to be reachable without paying,
    /// which is why it is on the hard paywall as well as in settings.
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

    /// Buys a product directly. Only the fallback paywall uses this; the
    /// dashboard paywall does its own buying.
    func purchase(_ product: StoreProduct) async {
        guard Purchases.isConfigured, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(product: product)
            guard !result.userCancelled else { return }
            apply(result.customerInfo)
            AnalyticsManager.shared.trackPurchaseCompleted(
                productID: product.productIdentifier, source: "fallback_paywall"
            )
        } catch {
            // A cancel is a decision, not a failure, and gets no alert.
            guard !Self.isCancellation(error) else { return }
            errorMessage = Self.message(for: error)
            CrashReporter.shared.record(error, context: "purchase")
            AnalyticsManager.shared.trackPurchaseFailed(reason: Self.reason(for: error))
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
    /// Drops the app into a given state so the paywall can be looked at without
    /// waiting seven days for it.
    func overrideStateForTesting(_ newState: AccessState) {
        state = newState
    }
    #endif
}

#if DEBUG
/// Launch arguments that stand a debug build at the end of the trial.
///
/// `-forceAccessState locked` holds the state there whatever the store and the
/// clock say, and `-forceHardPaywall YES|NO` answers for the console's
/// `hard_paywall_enabled`, so both presentations can be looked at on demand.
nonisolated enum DebugAccessOverride {

    static var state: AccessState? {
        switch UserDefaults.standard.string(forKey: "forceAccessState") {
        case "locked": .locked
        case "unlocked": .unlocked(.entitlement)
        default: nil
        }
    }

    static var isHardPaywallEnabled: Bool? {
        guard UserDefaults.standard.object(forKey: "forceHardPaywall") != nil else { return nil }
        return UserDefaults.standard.bool(forKey: "forceHardPaywall")
    }
}
#endif
