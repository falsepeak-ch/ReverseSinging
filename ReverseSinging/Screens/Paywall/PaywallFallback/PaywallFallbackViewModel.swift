//
//  PaywallFallbackViewModel.swift
//  ReverseSinging
//
//  The product, the purchase and the restore behind the app's own paywall
//

import SwiftUI
import Combine
import RevenueCat

/// Behind the fallback paywall: finding something to sell when the dashboard's paywall could
/// not be loaded, and buying or restoring it.
@MainActor
final class PaywallFallbackViewModel: ObservableObject {

    @Published private(set) var product: StoreProduct?
    @Published private(set) var isLoading = true

    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    init() {
        access = AccessController.shared

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var isRestoring: Bool { access.isRestoring }

    var isPurchasing: Bool { access.isPurchasing }

    /// Keyed off the access state rather than off how the paywall was presented: the
    /// presentation is a good proxy for "the trial is over" but not the fact itself, and this
    /// is the one line on the screen that must not be able to say something the user can see
    /// is untrue.
    var headerMessage: String {
        access.isLocked
            ? Strings.Pro.Fallback.messageAfterExpiry
            : Strings.Pro.Fallback.messageBeforeExpiry
    }

    // MARK: - Loading

    func loadProduct(force: Bool = false) async {
        guard force || product == nil else { return }
        guard Purchases.isConfigured else {
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Try the offering first even here: the earlier failure may have been a
        // blip, and the offering is the source of truth for what is on sale.
        // With one button to offer, the lifetime purchase comes first where the offering has
        // it, then the yearly plan, rather than whichever package happens to be listed first.
        if let current = try? await Purchases.shared.offerings().current,
           let package = current.lifetime ?? current.annual ?? current.availablePackages.first {
            product = package.storeProduct
            return
        }

        product = await Purchases.shared
            .products([PurchaseConfiguration.lifetimeProductID])
            .first
    }

    func retry() {
        Task { await loadProduct(force: true) }
    }

    // MARK: - Wording

    /// A subscription's price means nothing without its period, and Apple requires it on the button.
    func buyTitle(for product: StoreProduct) -> String {
        let price = product.localizedPriceString
        guard product.productType == .autoRenewableSubscription else {
            return String(format: Strings.Pro.Fallback.buy, price)
        }
        switch product.subscriptionPeriod?.unit {
        case .month: return String(format: Strings.Pro.Fallback.subscribeMonthly, price)
        case .year: return String(format: Strings.Pro.Fallback.subscribeYearly, price)
        default: return String(format: Strings.Pro.Fallback.subscribe, price)
        }
    }

    /// The line under the button. "Not a subscription" is only true of the lifetime purchase; a
    /// subscription gets the renewal terms instead.
    func purchaseNote(for product: StoreProduct) -> String {
        product.productType == .autoRenewableSubscription
            ? Strings.Pro.Fallback.renews
            : Strings.Pro.Fallback.oneTime
    }

    // MARK: - Purchase

    func buy(_ product: StoreProduct) {
        Task { await access.purchase(product) }
    }

    /// Always reachable, price or no price: someone who already paid must be able to get back
    /// in even when nothing else on this screen works.
    func restore() {
        Task { await access.restore() }
    }

    /// Apple's standard licence agreement, which is the one the app ships under. Required on any
    /// screen that sells an auto-renewable subscription.
    func openTermsOfUse() {
        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            UIApplication.shared.open(url)
        }
    }

    func openPrivacyPolicy() {
        if let url = URL(string: "https://falsepeak.ch/privacy") {
            UIApplication.shared.open(url)
        }
    }
}
