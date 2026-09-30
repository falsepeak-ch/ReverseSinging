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
/// It is wrapped rather than used directly for one reason. A store that will not
/// load leaves `PaywallView` on a spinner, with nothing to buy and no Restore. So
/// the offering is fetched here first, and if it never arrives the app draws its
/// own paywall — with a working restore button — instead.
struct ProPaywallView: View {

    @StateObject private var viewModel: ProPaywallViewModel
    @Environment(\.dismiss) private var dismiss

    /// - Parameter source: what put this on screen, for analytics. Not shown.
    init(source: String) {
        self.source = source
        _viewModel = StateObject(wrappedValue: ProPaywallViewModel(source: source))
    }

    private let source: String

    var body: some View {
        #if os(macOS)
        // The dashboard paywall is drawn for a phone. The Mac draws its own from the same
        // offering; see `MacPaywallView`.
        MacPaywallView(source: source)
        #else
        dashboardPaywall
        #endif
    }

    private var dashboardPaywall: some View {
        Group {
            if let offering = viewModel.offering {
                PaywallView(offering: offering, displayCloseButton: true)
                    .onPurchaseCompleted { transaction, customerInfo in
                        viewModel.purchaseCompleted(transaction, customerInfo)
                    }
                    .onRestoreCompleted { customerInfo in
                        viewModel.restoreCompleted(customerInfo)
                    }
                    .onPurchaseFailure { error in
                        viewModel.purchaseFailed(error)
                    }
                    // Tapping RevenueCat's own close button, where it renders one.
                    .onRequestedDismissal { viewModel.close() }
                    .overlay(alignment: .topTrailing) { closeButton }
            } else if viewModel.loadFailed {
                PaywallFallbackView(source: viewModel.source)
            } else {
                loading
            }
        }
        .task { await viewModel.loadOffering() }
        .onAppear { viewModel.onAppear() }
        .onChange(of: viewModel.isPro) { _, isPro in
            viewModel.isProDidChange(isPro)
        }
        .onChange(of: viewModel.shouldClose) { _, shouldClose in
            if shouldClose { dismiss() }
        }
    }

    /// The app's own way out of the paywall.
    ///
    /// `PaywallView(displayCloseButton:)` is asked for one too, but a paywall
    /// built as a workflow in the dashboard does not render one on its first page,
    /// which left the sheet with no visible exit — swipe-to-dismiss still worked,
    /// so it was not a trap, but a paywall whose only escape is an undiscoverable
    /// gesture fails anyone using VoiceOver or Switch Control, and reads as a dark
    /// pattern to everyone else.
    private var closeButton: some View {
        Button(action: viewModel.close) {
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

    private var loading: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()
            ProgressView()
                .tint(Color.rsHighlight)
        }
    }
}
