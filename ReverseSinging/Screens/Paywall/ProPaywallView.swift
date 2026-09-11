//
//  ProPaywallView.swift
//  ReverseSinging
//
//  The paywall. RevenueCat's when it can be reached, the app's own when it cannot.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

/// Presents the offering configured in the RevenueCat dashboard.
///
/// `PaywallView` fetches the current offering itself and renders whatever was
/// designed there, which is the point of using it: the copy, the price and the
/// artwork change without a release.
///
/// It is wrapped rather than used directly for one reason. When it is presented as
/// a *hard* paywall there is nothing behind it, so a store that will not load
/// leaves the user staring at a spinner with no way back into the app. So the
/// offering is fetched here first, and if it never arrives the app draws its own
/// paywall — with a working restore button — instead.
struct ProPaywallView: View {

    /// What put this on screen, for analytics. Not shown.
    let source: String

    /// A hard paywall has no close button and cannot be swiped away.
    var isDismissible: Bool = true

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var access = AccessController.shared

    @State private var offering: Offering?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let offering {
                PaywallView(offering: offering, displayCloseButton: isDismissible)
                    .onPurchaseCompleted { customerInfo in
                        access.handleCompletion(customerInfo)
                        AnalyticsManager.shared.trackPurchaseCompleted(
                            productID: offering.availablePackages.first?
                                .storeProduct.productIdentifier ?? PurchaseConfiguration.lifetimeProductID,
                            source: source
                        )
                        close()
                    }
                    .onRestoreCompleted { customerInfo in
                        access.handleCompletion(customerInfo)
                        AnalyticsManager.shared.trackRestoreCompleted(
                            foundEntitlement: access.isPro
                        )
                        // Only leave if the restore actually bought them back in.
                        // Closing a hard paywall on a restore that found nothing
                        // would drop them into an app they still cannot use.
                        if access.isPro { close() }
                    }
                    .onPurchaseFailure { error in
                        CrashReporter.shared.record(error, context: "paywall_purchase")
                    }
                    // Tapping RevenueCat's own close button, where it renders one.
                    .onRequestedDismissal { close() }
                    .overlay(alignment: .topTrailing) { closeButton }
            } else if loadFailed {
                PaywallFallbackView(source: source, isDismissible: isDismissible)
            } else {
                loading
            }
        }
        .interactiveDismissDisabled(!isDismissible)
        .task { await loadOffering() }
        .onAppear {
            AnalyticsManager.shared.trackPaywallShown(
                source: source, isHardPaywall: !isDismissible
            )
        }
        // A purchase that lands while this is open — through the paywall, a
        // restore, or a Family Sharing grant arriving on the stream — closes it.
        .onChange(of: access.isPro) { _, isPro in
            if isPro { close() }
        }
    }

    /// The app's own way out of a dismissible paywall.
    ///
    /// `PaywallView(displayCloseButton:)` is passed the same flag, but a paywall
    /// built as a workflow in the dashboard does not render one on its first page,
    /// which left the sheet with no visible exit — swipe-to-dismiss still worked,
    /// so it was not a trap, but a paywall whose only escape is an undiscoverable
    /// gesture fails anyone using VoiceOver or Switch Control, and reads as a dark
    /// pattern to everyone else.
    ///
    /// Owned here rather than fixed in the dashboard because dismissibility is the
    /// app's decision: the same paywall is a sheet in one place and the hard
    /// paywall in another, and only this side knows which.
    @ViewBuilder
    private var closeButton: some View {
        if isDismissible {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.rsTextPrimary)
                    .frame(width: 32, height: 32)
                    // A backdrop so it stays visible whatever the dashboard puts
                    // behind it later.
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
            .accessibilityLabel(Strings.Pro.closePaywall)
        }
    }

    private var loading: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()
            ProgressView()
                .tint(Color.rsHighlight)
        }
    }

    // MARK: - Loading

    private func loadOffering() async {
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

    private func close() {
        AnalyticsManager.shared.trackPaywallDismissed(source: source)
        dismiss()
    }
}
