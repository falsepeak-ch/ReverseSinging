//
//  MacPaywallViewModel.swift
//  DubloonMac
//
//  The offering as a choice of plans, and the purchase of the one picked
//

import SwiftUI
import Combine
import RevenueCat

/// Drives the Mac's own paywall.
///
/// The iPhone shows the paywall designed in the RevenueCat dashboard, which is drawn for a
/// phone. The Mac draws its own, from the same offering: what is on sale, and which experiment
/// arm this install sees, still come from the dashboard. The analytics and closing
/// rules are `ProPaywallViewModel`'s, and buying and restoring are `PaywallFallbackViewModel`'s,
/// so all three paywalls behave the same.
@MainActor
final class MacPaywallViewModel: ObservableObject {

    let paywall: ProPaywallViewModel
    let store: PaywallFallbackViewModel

    /// The package the user has picked. Starts on the best one on offer.
    @Published var selectedPackageID: String?

    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    init(source: String) {
        paywall = ProPaywallViewModel(source: source)
        store = PaywallFallbackViewModel()
        access = AccessController.shared

        for publisher in [paywall.objectWillChange, store.objectWillChange] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    // MARK: - Screen

    func onAppear() {
        paywall.onAppear()
    }

    func load() async {
        await paywall.loadOffering()
        if paywall.loadFailed {
            // The offering is gone; the fallback still finds one product to sell.
            await store.loadProduct()
        }
        if selectedPackageID == nil { selectedPackageID = defaultPackage?.identifier }
    }

    // MARK: - Plans

    /// What is on sale, best value first: the lifetime purchase, then yearly, then monthly.
    var packages: [Package] {
        guard let offering = paywall.offering else { return [] }
        let order: [PackageType] = [.lifetime, .annual, .sixMonth, .threeMonth, .twoMonth, .monthly, .weekly]
        return offering.availablePackages.sorted {
            (order.firstIndex(of: $0.packageType) ?? order.count) < (order.firstIndex(of: $1.packageType) ?? order.count)
        }
    }

    private var defaultPackage: Package? {
        guard let offering = paywall.offering else { return nil }
        return offering.lifetime ?? offering.annual ?? packages.first
    }

    var selectedPackage: Package? {
        packages.first { $0.identifier == selectedPackageID } ?? defaultPackage
    }

    /// The product the primary button buys: the picked plan, or the fallback's.
    var product: StoreProduct? {
        selectedPackage?.storeProduct ?? store.product
    }

    var isLoading: Bool {
        (paywall.offering == nil && !paywall.loadFailed) || (paywall.loadFailed && store.isLoading)
    }

    var isUnavailable: Bool {
        !isLoading && product == nil
    }

    var isBusy: Bool { store.isPurchasing || store.isRestoring }

    // MARK: - Wording

    /// A plan's name as App Store Connect gives it, in the user's language.
    func title(for package: Package) -> String {
        let name = package.storeProduct.localizedTitle
        return name.isEmpty ? package.storeProduct.productIdentifier : name
    }

    /// Price and period, as Apple requires for a subscription, the period in the system's words.
    func priceLine(for package: Package) -> String {
        let product = package.storeProduct
        guard let period = product.subscriptionPeriod, let length = Self.format(period) else {
            return product.localizedPriceString
        }
        return "\(product.localizedPriceString) · \(length)"
    }

    private static func format(_ period: SubscriptionPeriod) -> String? {
        var components = DateComponents()
        switch period.unit {
        case .day: components.day = period.value
        case .week: components.weekOfMonth = period.value
        case .month: components.month = period.value
        case .year: components.year = period.value
        @unknown default: return nil
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        return formatter.string(from: components)
    }

    /// How long the free trial runs, such as "1 week"; shown beside a gift, so no price is needed.
    func introLine(for package: Package) -> String? {
        guard let intro = package.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial,
              let length = Self.format(intro.subscriptionPeriod) else { return nil }
        return length
    }

    var buyTitle: String {
        product.map(store.buyTitle(for:)) ?? Strings.Pro.Fallback.buyUnpriced
    }

    var purchaseNote: String? {
        product.map(store.purchaseNote(for:))
    }

    // MARK: - Actions

    func buy() {
        guard !isBusy else { return }
        if let package = selectedPackage {
            let source = paywall.source
            Task { await access.purchase(package, source: source) }
        } else if let product = store.product {
            store.buy(product)
        }
    }

    func restore() {
        store.restore()
    }

    func retry() {
        Task {
            await paywall.loadOffering()
            await store.loadProduct(force: true)
        }
    }

    func close() {
        paywall.close()
    }
}
