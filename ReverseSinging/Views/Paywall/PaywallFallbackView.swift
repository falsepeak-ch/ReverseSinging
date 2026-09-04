//
//  PaywallFallbackView.swift
//  ReverseSinging
//
//  The paywall the app draws when the dashboard's cannot be loaded.
//

import SwiftUI
import RevenueCat

/// A plain, local paywall for the case where `PaywallView` has nothing to render.
///
/// It exists because the hard paywall covers the whole app: if the offering fails
/// to load there is no screen behind it to go back to, and a user who has already
/// paid would be locked out of something they own by a bad connection. So this
/// asks the store for one known product identifier — the only place in the app
/// that hardcodes one — and, more importantly, always offers Restore.
///
/// It is not a second design to maintain. It is the lifeboat, and it should look
/// like the rest of the editor chrome and nothing more.
struct PaywallFallbackView: View {

    let source: String
    var isDismissible: Bool = true

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var access = AccessController.shared

    @State private var product: StoreProduct?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()

            VStack(spacing: 0) {
                if isDismissible {
                    closeBar
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        benefits
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, EditorMetrics.gutter)
                    .padding(.top, 32)
                }

                actions
            }
        }
        .purchaseAlerts()
        .task { await loadProduct() }
    }

    // MARK: - Pieces

    private var closeBar: some View {
        HStack {
            Spacer()
            EditorToolbarButton(icon: "xmark", label: Strings.Pro.ok) { dismiss() }
        }
        .padding(.horizontal, EditorMetrics.gutter)
        .padding(.top, 12)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.Pro.Fallback.title)
                .font(.rsDisplayMedium)
                .foregroundStyle(Color.rsTextPrimary)

            // Keyed off the access state rather than off `isDismissible`: the
            // presentation is a good proxy for "the trial is over" but not the
            // fact itself, and this is the one line on the screen that must not
            // be able to say something the user can see is untrue.
            Text(access.isLocked
                 ? Strings.Pro.Fallback.messageAfterExpiry
                 : Strings.Pro.Fallback.messageBeforeExpiry)
                .font(.rsBodyMedium)
                .foregroundStyle(Color.rsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorSectionHeader(title: Strings.Pro.section)

            ForEach(
                [
                    Strings.Pro.Fallback.benefitOne,
                    Strings.Pro.Fallback.benefitTwo,
                    Strings.Pro.Fallback.benefitThree
                ],
                id: \.self
            ) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.rsHighlight)

                    Text(benefit)
                        .font(.rsBodyMedium)
                        .foregroundStyle(Color.rsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(14)
                .editorPanel()
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(Color.rsHighlight)
                    .frame(height: 52)
            } else if let product {
                buyButton(for: product)

                Text(Strings.Pro.Fallback.oneTime)
                    .font(.rsCaptionSmall)
                    .foregroundStyle(Color.rsTextTertiary)
            } else {
                Text(Strings.Pro.Fallback.unavailable)
                    .font(.rsBodySmall)
                    .foregroundStyle(Color.rsTextSecondary)
                    .multilineTextAlignment(.center)

                Button(Strings.Pro.Fallback.retry) {
                    Task { await loadProduct(force: true) }
                }
                .font(.rsButtonMedium)
                .foregroundStyle(Color.rsHighlight)
            }

            // Always reachable, price or no price: someone who already paid must
            // be able to get back in even when nothing else on this screen works.
            Button {
                Task { await access.restore() }
            } label: {
                if access.isRestoring {
                    ProgressView().tint(Color.rsTextSecondary)
                } else {
                    Text(Strings.Pro.restoreTitle)
                        .font(.rsButtonSmall)
                        .foregroundStyle(Color.rsTextSecondary)
                }
            }
            .disabled(access.isRestoring)

            Button(Strings.Settings.privacyPolicy) {
                if let url = URL(string: "https://falsepeak.ch/privacy") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.rsCaptionSmall)
            .foregroundStyle(Color.rsTextTertiary)
        }
        .padding(.horizontal, EditorMetrics.gutter)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(Color.rsSurface1.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { EditorRule() }
    }

    private func buyButton(for product: StoreProduct) -> some View {
        Button {
            HapticManager.shared.medium()
            Task { await access.purchase(product) }
        } label: {
            Group {
                if access.isPurchasing {
                    ProgressView().tint(Color.rsSurface0)
                } else {
                    Text(String(format: Strings.Pro.Fallback.buy, product.localizedPriceString))
                        .font(.rsButtonLarge)
                        .foregroundStyle(Color.rsSurface0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .fill(Color.rsTextPrimary)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(access.isPurchasing)
    }

    // MARK: - Loading

    private func loadProduct(force: Bool = false) async {
        guard force || product == nil else { return }
        guard Purchases.isConfigured else {
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Try the offering first even here: the earlier failure may have been a
        // blip, and the offering is the source of truth for what is on sale.
        if let current = try? await Purchases.shared.offerings().current,
           let package = current.availablePackages.first {
            product = package.storeProduct
            return
        }

        product = await Purchases.shared
            .products([PurchaseConfiguration.lifetimeProductID])
            .first
    }
}
