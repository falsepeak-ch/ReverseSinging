//
//  ProPaywallViewModel.swift
//  ReverseSinging
//
//  Loads the dashboard's offering, and reacts to what happens on the paywall
//

import Foundation
import Combine
import RevenueCat

/// Behind the paywall: fetching the offering before RevenueCat's own paywall is shown, and
/// what a purchase, a restore or a failure does once it has.
@MainActor
final class ProPaywallViewModel: ObservableObject {

    /// What put this on screen, for analytics. Not shown.
    let source: String

    @Published private(set) var offering: Offering?
    @Published private(set) var loadFailed = false
    /// Set when the paywall has done its job and should go.
    @Published private(set) var shouldClose = false

    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    init(source: String) {
        self.source = source
        access = AccessController.shared

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var isPro: Bool { access.isPro }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackPaywallShown(source: source)
    }

    /// A purchase that lands while this is open — through the paywall, a restore, or a Family
    /// Sharing grant arriving on the stream — closes it.
    func isProDidChange(_ isPro: Bool) {
        if isPro { close() }
    }

    // MARK: - Loading

    func loadOffering() async {
        guard offering == nil, Purchases.isConfigured else {
            if !Purchases.isConfigured { loadFailed = true }
            return
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            var current = offerings.current
            #if DEBUG
            // `-paywallOffering <id>` previews another arm of the experiment.
            if let id = UserDefaults.standard.string(forKey: "paywallOffering") {
                current = offerings.offering(identifier: id) ?? current
            }
            #endif
            guard let current else {
                // Configured, reachable, and nothing is on sale. A dashboard
                // problem rather than a network one, and worth reporting.
                CrashReporter.shared.recordFailure(
                    "paywall_no_current_offering",
                    reason: "Offerings loaded but none is marked current"
                )
                loadFailed = true
                return
            }
            offering = current
        } catch {
            CrashReporter.shared.record(error, context: "paywall_offerings")
            loadFailed = true
        }
    }

    // MARK: - Paywall Events

    /// The product comes from the transaction, not the offering: an offering can hold more than
    /// one package (monthly and yearly), and guessing the first would misreport the experiment.
    func purchaseCompleted(_ transaction: StoreTransaction?, _ customerInfo: CustomerInfo) {
        access.handleCompletion(customerInfo)
        AnalyticsManager.shared.trackPurchaseCompleted(
            productID: transaction?.productIdentifier
                ?? offering?.availablePackages.first?.storeProduct.productIdentifier
                ?? PurchaseConfiguration.lifetimeProductID,
            source: source
        )
        close()
    }

    func restoreCompleted(_ customerInfo: CustomerInfo) {
        access.handleCompletion(customerInfo)
        AnalyticsManager.shared.trackRestoreCompleted(
            foundEntitlement: access.isPro
        )
        // Only leave if the restore actually bought them back in. After one that
        // found nothing, the offer they came for is still what they need to see.
        if access.isPro { close() }
    }

    func purchaseFailed(_ error: Error) {
        AccessController.reportPurchaseFailure(error, context: "paywall_purchase")
    }

    func close() {
        AnalyticsManager.shared.trackPaywallDismissed(source: source)
        shouldClose = true
    }
}
