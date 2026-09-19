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

    /// A hard paywall has no close button and cannot be swiped away.
    let isDismissible: Bool

    @Published private(set) var offering: Offering?
    @Published private(set) var loadFailed = false
    /// Set when the paywall has done its job and should go.
    @Published private(set) var shouldClose = false

    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    init(source: String, isDismissible: Bool) {
        self.source = source
        self.isDismissible = isDismissible
        access = AccessController.shared

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var isPro: Bool { access.isPro }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackPaywallShown(
            source: source, isHardPaywall: !isDismissible
        )
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
            guard let current = offerings.current else {
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

    func purchaseCompleted(_ customerInfo: CustomerInfo) {
        access.handleCompletion(customerInfo)
        AnalyticsManager.shared.trackPurchaseCompleted(
            productID: offering?.availablePackages.first?
                .storeProduct.productIdentifier ?? PurchaseConfiguration.lifetimeProductID,
            source: source
        )
        close()
    }

    func restoreCompleted(_ customerInfo: CustomerInfo) {
        access.handleCompletion(customerInfo)
        AnalyticsManager.shared.trackRestoreCompleted(
            foundEntitlement: access.isPro
        )
        // Only leave if the restore actually bought them back in.
        // Closing a hard paywall on a restore that found nothing
        // would drop them into an app they still cannot use.
        if access.isPro { close() }
    }

    func purchaseFailed(_ error: Error) {
        CrashReporter.shared.record(error, context: "paywall_purchase")
    }

    func close() {
        AnalyticsManager.shared.trackPaywallDismissed(source: source)
        shouldClose = true
    }
}
