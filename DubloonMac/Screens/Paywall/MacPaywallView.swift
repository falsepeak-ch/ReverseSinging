//
//  MacPaywallView.swift
//  DubloonMac
//
//  Dubloon Pro, as a Mac sheet: what it opens, the plans, and a Buy button on Return
//

import SwiftUI
import RevenueCat

/// The paywall drawn the way a Mac app asks for money: a compact sheet with the app's icon,
/// a short list of what the purchase opens, the plans as a choice, and the standard footer of
/// Restore and the legal links on the left, Cancel and a default button on the right.
struct MacPaywallView: View {
    @StateObject private var viewModel: MacPaywallViewModel
    @Environment(\.dismiss) private var dismiss

    init(source: String, isDismissible: Bool) {
        _viewModel = StateObject(wrappedValue: MacPaywallViewModel(source: source, isDismissible: isDismissible))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 22) {
                header
                benefits
                plans
            }
            .padding(.horizontal, 36)
            .padding(.top, 30)
            .padding(.bottom, 24)

            footer
        }
        // As tall as what is on sale needs, the way a Mac sheet sizes itself.
        .frame(width: 600)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.rsSurface1)
        .interactiveDismissDisabled(!viewModel.paywall.isDismissible)
        .task { await viewModel.load() }
        .onAppear { viewModel.onAppear() }
        .onChange(of: viewModel.paywall.isPro) { _, isPro in viewModel.paywall.isProDidChange(isPro) }
        .onChange(of: viewModel.paywall.shouldClose) { _, shouldClose in if shouldClose { dismiss() } }
        .purchaseAlerts()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)

            Text(Strings.Pro.section)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.rsTextPrimary)

            Text(Strings.Pro.Fallback.messageNoTrial)
                .font(.system(size: 13))
                .foregroundColor(.rsTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit(image: GameMode.dub.image, title: GameMode.dub.title, detail: Strings.Pro.Fallback.benefitTwo)
            benefit(image: GameMode.imitate.image, title: GameMode.imitate.title, detail: GameMode.imitate.subtitle)
            benefit(image: "settings-booth-cam", title: Strings.Booth.settingsTitle, detail: Strings.Pro.Fallback.benefitOne)
            benefit(image: "film-reel", title: Strings.Dub.export, detail: Strings.Pro.Fallback.benefitThree)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.rsSurface2))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.rsStroke, lineWidth: 1))
    }

    /// Every row wears one of the app's own illustrations, like the rest of the app.
    private func benefit(image: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.rsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        if viewModel.isLoading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(Strings.Pro.Fallback.loading)
                    .font(.system(size: 12))
                    .foregroundColor(.rsTextSecondary)
            }
            .frame(height: 70)
        } else if viewModel.isUnavailable {
            VStack(spacing: 8) {
                Text(Strings.Pro.Fallback.unavailable)
                    .font(.system(size: 12))
                    .foregroundColor(.rsTextSecondary)
                    .multilineTextAlignment(.center)
                Button(Strings.Pro.Fallback.retry) { viewModel.retry() }
            }
        } else if viewModel.packages.count > 1 {
            HStack(spacing: 12) {
                ForEach(viewModel.packages, id: \.identifier) { package in
                    planCard(package)
                }
            }
        }
    }

    private func planCard(_ package: Package) -> some View {
        let isSelected = viewModel.selectedPackage?.identifier == package.identifier
        return Button {
            viewModel.selectedPackageID = package.identifier
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? .accentColor : .rsTextTertiary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.title(for: package))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.rsTextPrimary)
                    Text(viewModel.priceLine(for: package))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundColor(.rsTextSecondary)
                    if let intro = viewModel.introLine(for: package) {
                        Label(intro, systemImage: "gift")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.rsGood)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.accentColor.opacity(0.12) : Color.rsSurface2))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : Color.rsStroke, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Footer

    /// The buttons on the right as on any Mac sheet, never truncated: a price cut short is not
    /// a price. The legal links sit under them, where a Mac sheet keeps its small print.
    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let note = viewModel.purchaseNote {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(.rsTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if viewModel.isBusy {
                    ProgressView().controlSize(.small)
                }

                if viewModel.paywall.isDismissible {
                    Button(Strings.Main.Alert.cancel) { viewModel.close() }
                        .keyboardShortcut(.cancelAction)
                        .controlSize(.large)
                        .fixedSize()
                }

                Button(viewModel.buyTitle) { viewModel.buy() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .fixedSize()
                    .disabled(viewModel.product == nil || viewModel.isBusy)
            }

            HStack(spacing: 16) {
                Button(Strings.Pro.restoreTitle) { viewModel.restore() }
                    .disabled(viewModel.isBusy)
                Button(Strings.Pro.Fallback.terms) { viewModel.store.openTermsOfUse() }
                Button(Strings.Settings.privacyPolicy) { viewModel.store.openPrivacyPolicy() }
                Spacer()
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Color.rsSurface2)
        .overlay(alignment: .top) { EditorRule() }
    }
}
