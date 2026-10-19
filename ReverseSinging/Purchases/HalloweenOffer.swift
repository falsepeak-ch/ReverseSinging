//
//  HalloweenOffer.swift
//  ReverseSinging
//
//  The Halloween deal: the first year of the yearly plan at its introductory price, for two
//  weeks, offered from a banner over the games.
//

import Combine
import Foundation
import RevenueCat

/// What the Halloween banner shows: the store's two prices and the deal's last moment.
struct HalloweenDeal: Equatable {
    let introPrice: String
    let renewalPrice: String
    let endDate: Date
}

/// Whether the Halloween deal is on, what it costs, and buying it.
///
/// The price is not written here. App Store Connect holds it, as a pay-up-front introductory
/// offer on the yearly plan, dated to the same two weeks; this reads it back from the store.
/// So the banner only appears once the store would really charge what it says, in the
/// buyer's currency, and only to someone the store still counts as eligible for an
/// introductory offer (a first subscription in the group).
@MainActor
final class HalloweenOffer: ObservableObject {

    static let shared = HalloweenOffer()

    /// The first day of the deal, and the day after the last, in the phone's own time zone. The
    /// store's offer runs a day longer, so no time zone ever sees the banner after the price
    /// has gone back up.
    nonisolated static let startDate = localMidnight(year: 2026, month: 10, day: 20)
    nonisolated static let endDate = localMidnight(year: 2026, month: 11, day: 3)

    /// The first year, as the store charges it (`2,99 €`). Nil until the store has answered,
    /// and nil when it has no such offer for this buyer.
    @Published private(set) var introPrice: String?
    /// What each year after the first costs, which the banner has to say alongside.
    @Published private(set) var renewalPrice: String?

    private var product: StoreProduct?
    private var isLoading = false
    private let access: AccessController
    private let switches: BannerSwitches
    private var cancellables = Set<AnyCancellable>()

    /// A purchase hides the banner, and the purchase spinner shows on it; the console's switch
    /// hides it too. Both models' changes are passed on as this one's own.
    init(access: AccessController = .shared, switches: BannerSwitches = .shared) {
        self.access = access
        self.switches = switches
        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        switches.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// The deal's dates are running, at `now`.
    nonisolated static func isRunning(at now: Date = Date()) -> Bool {
        now >= startDate && now < endDate
    }

    /// The banner is shown: nothing has been bought, the dates are running, the store has the
    /// offer for this buyer, and Remote Config has not switched it off (`BannerSwitches`).
    func isShown(at now: Date = Date()) -> Bool {
        switches.isHalloweenBannerEnabled
            && access.isLocked
            && Self.isRunning(at: now)
            && introPrice != nil
            && renewalPrice != nil
    }

    /// What the banner says, or nil while it is not shown.
    func deal(at now: Date = Date()) -> HalloweenDeal? {
        guard isShown(at: now), let introPrice, let renewalPrice else { return nil }
        return HalloweenDeal(introPrice: introPrice, renewalPrice: renewalPrice, endDate: Self.endDate)
    }

    var isPurchasing: Bool { access.isPurchasing }

    // MARK: - Loading

    /// Asks the store for the yearly plan and its introductory offer, once.
    func load() async {
        guard introPrice == nil, !isLoading, Self.isRunning() else { return }
        #if DEBUG
        // `-forceHalloweenOffer YES` shows the banner on a store without the offer (the Test
        // Store has none), with sample prices. Tapping it does nothing.
        if UserDefaults.standard.bool(forKey: "forceHalloweenOffer") {
            introPrice = "$2.99"
            renewalPrice = "$5.99"
            return
        }
        #endif
        guard Purchases.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }

        let products = await Purchases.shared.products([PurchaseConfiguration.yearlyProductID])
        guard let yearly = products.first,
              let intro = yearly.introductoryDiscount,
              intro.paymentMode == .payUpFront else { return }

        // An introductory offer is only for a first subscription in the group: someone who
        // already had the free trial would be charged the full price, which the banner must
        // not promise. Unknown (no receipt yet, as on a fresh install) is let through: the
        // store decides at checkout, and a newcomer is exactly who this is for.
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: yearly)
        guard eligibility != .ineligible, eligibility != .noIntroOfferExists else { return }

        product = yearly
        introPrice = intro.localizedPriceString
        renewalPrice = yearly.localizedPriceString
    }

    // MARK: - Buying

    /// Opens the store's own sheet for the yearly plan; the introductory price is applied there.
    func purchase(source: String) async {
        guard let product else { return }
        AnalyticsManager.shared.trackCustomEvent(name: "halloween_offer_tapped", parameters: ["source": source])
        await access.purchase(product, source: source)
    }

    // MARK: - Dates

    nonisolated private static func localMidnight(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}
