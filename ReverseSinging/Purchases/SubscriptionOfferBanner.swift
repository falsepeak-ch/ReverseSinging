//
//  SubscriptionOfferBanner.swift
//  ReverseSinging
//
//  Which subscription offer, if any, this person can take right now: the introductory
//  offer for someone who never subscribed, or a win-back offer for someone who lapsed.
//

import Combine
import Foundation
import RevenueCat

/// One offer, worded for the menu.
struct SubscriptionOffer: Equatable {
    enum Kind: String {
        /// A first subscription, with the product's introductory offer.
        case intro
        /// A lapsed subscriber, with an App Store win-back offer.
        case winBack = "win_back"
    }

    let kind: Kind
    let productID: String
    let title: String
    let subtitle: String
}

/// Finds the offer to show on the menu and remembers when it was waved away.
///
/// Only ever has something to say to someone who is locked: an active subscriber, a lifetime
/// owner and an early adopter all have the app, so there is nothing to offer them. Eligibility
/// is the store's answer, never a guess: RevenueCat's intro-eligibility check for a newcomer,
/// and StoreKit's win-back eligibility (through RevenueCat, iOS 18 and later) for someone whose
/// subscription ran out.
@MainActor
final class SubscriptionOfferBanner: ObservableObject {

    static let shared = SubscriptionOfferBanner()

    @Published private(set) var offer: SubscriptionOffer?

    /// The win-back offer behind `offer`, kept to buy it with. `WinBackOffer` is iOS 18 only.
    private var winBackProduct: StoreProduct?
    private var winBackOffer: Any?
    private var isLoading = false

    private let defaults: UserDefaults
    private let pacing: OfferBannerPacing

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pacing = OfferBannerPacing(defaults: defaults)
    }

    /// Whether the banner may be on screen now: there is an offer, and it was not waved away
    /// recently.
    var isVisible: Bool { offer != nil && pacing.mayShow() }

    // MARK: - Finding

    /// Asks the store what this person is eligible for. Cheap enough for every menu appearance.
    func refresh(access: AccessController) async {
        #if DEBUG
        // App Store screenshots never show the offer, nor ask RevenueCat for one.
        if ScreenshotMode.isActive { clear(); return }
        #endif
        guard Purchases.isConfigured, access.isLocked, !isLoading else {
            if !access.isLocked { clear() }
            return
        }
        isLoading = true
        defer { isLoading = false }

        guard let offering = try? await Purchases.shared.offerings().current else {
            clear()
            return
        }
        let subscriptions = offering.availablePackages.filter { $0.storeProduct.subscriptionPeriod != nil }
        guard !subscriptions.isEmpty else {
            clear()
            return
        }

        if hadSubscription(access), #available(iOS 18.0, macOS 15.0, *),
           let found = await winBack(in: subscriptions) {
            apply(found)
            return
        }

        if let found = await intro(in: subscriptions) {
            apply(found)
            return
        }

        clear()
    }

    /// Someone whose Pro entitlement exists but is no longer active had a subscription once.
    private func hadSubscription(_ access: AccessController) -> Bool {
        guard let entitlement = access.entitlement else { return false }
        return !entitlement.isActive && entitlement.expirationDate != nil
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func winBack(in packages: [Package]) async -> (SubscriptionOffer, StoreProduct, Any)? {
        for package in packages {
            let product = package.storeProduct
            guard let offers = try? await Purchases.shared.eligibleWinBackOffers(forProduct: product),
                  let first = offers.first else { continue }
            let discount = first.discount
            let duration = OfferWording.duration(discount.subscriptionPeriod, count: discount.numberOfPeriods)
            let title = discount.price == 0
                ? String(format: Strings.Offer.winBackFree, duration)
                : String(format: Strings.Offer.winBackPaid, discount.localizedPriceString, duration)
            let offer = SubscriptionOffer(
                kind: .winBack,
                productID: product.productIdentifier,
                title: title,
                subtitle: String(format: Strings.Offer.then, OfferWording.regularPrice(product))
            )
            return (offer, product, first)
        }
        return nil
    }

    private func intro(in packages: [Package]) async -> (SubscriptionOffer, StoreProduct, Any)? {
        let withIntro = packages.filter { $0.storeProduct.introductoryDiscount != nil }
        guard !withIntro.isEmpty else { return nil }
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: withIntro)

        // A free trial reads best, so it wins over a discounted first period.
        let eligible = withIntro.filter { eligibility[$0]?.status == .eligible }
        guard let package = eligible.first(where: { $0.storeProduct.introductoryDiscount?.paymentMode == .freeTrial })
                ?? eligible.first,
              let discount = package.storeProduct.introductoryDiscount else { return nil }

        let product = package.storeProduct
        let duration = OfferWording.duration(discount.subscriptionPeriod, count: discount.numberOfPeriods)
        let title = discount.paymentMode == .freeTrial
            ? String(format: Strings.Offer.introFree, duration)
            : String(format: Strings.Offer.introPaid, discount.localizedPriceString, duration)
        let offer = SubscriptionOffer(
            kind: .intro,
            productID: product.productIdentifier,
            title: title,
            subtitle: String(format: Strings.Offer.then, OfferWording.regularPrice(product))
        )
        return (offer, product, NSNull())
    }

    private func apply(_ found: (SubscriptionOffer, StoreProduct, Any)) {
        let (newOffer, product, extra) = found
        if newOffer.kind == .winBack {
            winBackProduct = product
            winBackOffer = extra
        } else {
            winBackProduct = nil
            winBackOffer = nil
        }
        if offer != newOffer {
            offer = newOffer
        }
    }

    private func clear() {
        winBackProduct = nil
        winBackOffer = nil
        if offer != nil { offer = nil }
    }

    // MARK: - Acting

    /// Buys the win-back offer straight from the banner: the App Store's own sheet is the
    /// offer sheet. Returns false when there is no win-back offer to buy, so the caller can
    /// open the paywall instead.
    func redeemWinBack(access: AccessController) async -> Bool {
        guard #available(iOS 18.0, macOS 15.0, *),
              let product = winBackProduct,
              let offer = winBackOffer as? WinBackOffer else { return false }
        await access.purchase(product, winBackOffer: offer, source: "offer_banner")
        return true
    }

    /// Waved away: hidden for a while, and for good after a few times.
    func dismiss() {
        pacing.recordDismissal()
        objectWillChange.send()
    }

    #if DEBUG
    func resetPacingForTesting() {
        pacing.reset()
        objectWillChange.send()
    }
    #endif
}

/// The banner's rate limit, stored on the device: two weeks of quiet after each dismissal,
/// and never again after the third.
struct OfferBannerPacing {
    static let snooze: TimeInterval = 14 * 24 * 60 * 60
    static let maxDismissals = 3

    private let defaults: UserDefaults
    private let dismissedAtKey = "offerBanner.dismissedAt"
    private let dismissCountKey = "offerBanner.dismissCount"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func mayShow(now: Date = Date()) -> Bool {
        if defaults.integer(forKey: dismissCountKey) >= Self.maxDismissals { return false }
        guard let last = defaults.object(forKey: dismissedAtKey) as? Date else { return true }
        return now.timeIntervalSince(last) >= Self.snooze
    }

    func recordDismissal(now: Date = Date()) {
        defaults.set(now, forKey: dismissedAtKey)
        defaults.set(defaults.integer(forKey: dismissCountKey) + 1, forKey: dismissCountKey)
    }

    func reset() {
        defaults.removeObject(forKey: dismissedAtKey)
        defaults.removeObject(forKey: dismissCountKey)
    }
}

/// Durations and prices in the user's language, from what the store returned.
enum OfferWording {

    /// "1 week", "3 days", "1 year": the offer period times its count.
    static func duration(_ period: SubscriptionPeriod, count: Int) -> String {
        var components = DateComponents()
        let value = period.value * max(count, 1)
        switch period.unit {
        case .day: components.day = value
        case .week: components.weekOfMonth = value
        case .month: components.month = value
        case .year: components.year = value
        @unknown default: components.day = value
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        return formatter.string(from: components) ?? "\(value)"
    }

    /// "$2.99 / 1 month": what the subscription costs once the offer is over.
    static func regularPrice(_ product: StoreProduct) -> String {
        guard let period = product.subscriptionPeriod else { return product.localizedPriceString }
        return "\(product.localizedPriceString) / \(duration(period, count: 1))"
    }
}
