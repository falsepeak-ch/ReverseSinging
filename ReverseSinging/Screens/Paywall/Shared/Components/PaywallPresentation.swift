//
//  PaywallPresentation.swift
//  ReverseSinging
//
//  The two modifiers that put the paywall, and its outcomes, on screen.
//

import SwiftUI

extension View {

    /// Covers the whole app once the free window has closed.
    ///
    /// Attached at the root, above onboarding, so there is no screen it can be
    /// escaped onto. It is driven by `AccessController.state` rather than by a
    /// `@State` flag: nothing in the view layer can dismiss it, and a purchase
    /// arriving on the customer-info stream — from this device or another one —
    /// takes it away by itself.
    func hardPaywall() -> some View {
        modifier(HardPaywallModifier())
    }

    /// Reports what a purchase or a restore did.
    ///
    /// Attached to each screen that can start one, rather than once at the root.
    /// An alert presented from the root tears down any sheet above it, so a
    /// restore tapped in settings would answer by closing settings — which reads
    /// as the button having thrown the user out.
    func purchaseAlerts() -> some View {
        modifier(PurchaseAlertsModifier())
    }
}

private struct HardPaywallModifier: ViewModifier {
    @ObservedObject private var access = AccessController.shared

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: isLocked) {
                ProPaywallView(source: "trial_expired", isDismissible: false)
                    .preferredColorScheme(.dark)
            }
    }

    /// Read-only in practice. The setter is required by `fullScreenCover` and is
    /// deliberately inert: the cover goes away when the entitlement arrives, and
    /// there is no gesture or button that should be able to do it instead.
    private var isLocked: Binding<Bool> {
        Binding(get: { access.isLocked }, set: { _ in })
    }
}

private struct PurchaseAlertsModifier: ViewModifier {
    @ObservedObject private var access = AccessController.shared

    func body(content: Content) -> some View {
        content
            .alert(
                Strings.Pro.nothingToRestoreTitle,
                isPresented: $access.restoreFoundNothing
            ) {
                Button(Strings.Pro.ok, role: .cancel) {}
            } message: {
                Text(Strings.Pro.nothingToRestoreMessage)
            }
            .alert(
                Strings.Pro.errorTitle,
                isPresented: Binding(
                    get: { access.errorMessage != nil },
                    set: { if !$0 { access.errorMessage = nil } }
                )
            ) {
                Button(Strings.Pro.ok, role: .cancel) { access.errorMessage = nil }
            } message: {
                Text(access.errorMessage ?? Strings.Pro.errorGeneric)
            }
    }
}
