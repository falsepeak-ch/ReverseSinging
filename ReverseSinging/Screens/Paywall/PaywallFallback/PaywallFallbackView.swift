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
    @StateObject private var viewModel = PaywallFallbackViewModel()

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
        .task { await viewModel.loadProduct() }
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

            Text(viewModel.headerMessage)
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
            if viewModel.isLoading {
                ProgressView()
                    .tint(Color.rsHighlight)
                    .frame(height: 52)
            } else if let product = viewModel.product {
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
                    viewModel.retry()
                }
                .font(.rsButtonMedium)
                .foregroundStyle(Color.rsHighlight)
            }

            Button {
                viewModel.restore()
            } label: {
                if viewModel.isRestoring {
                    ProgressView().tint(Color.rsTextSecondary)
                } else {
                    Text(Strings.Pro.restoreTitle)
                        .font(.rsButtonSmall)
                        .foregroundStyle(Color.rsTextSecondary)
                }
            }
            .disabled(viewModel.isRestoring)

            Button(Strings.Settings.privacyPolicy) {
                viewModel.openPrivacyPolicy()
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
            viewModel.buy(product)
        } label: {
            Group {
                if viewModel.isPurchasing {
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
        .disabled(viewModel.isPurchasing)
    }
}
