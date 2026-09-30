//
//  PaywallPresentation.swift
//  ReverseSinging
//
//  The modifier that puts a purchase's or a restore's outcome on screen.
//

import SwiftUI

extension View {

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
