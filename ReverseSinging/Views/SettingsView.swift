//
//  SettingsView.swift
//  ReverseSinging
//
//  Premium settings page matching SessionList aesthetic
//

import SwiftUI
import RevenueCatUI

/// Which settings a presentation is allowed to show.
///
/// The menu owns nothing but the app itself, so opening settings from there must
/// not offer choices that belong to one game. The Simple/Complex interface is a
/// property of reverse singing, and is meaningless before a game is picked.
enum SettingsScope {
    case app
    case reverseSinging
}

struct SettingsView: View {
    @ObservedObject var viewModel: AudioViewModel

    /// Defaults to the narrow set; a game screen opts in to its own options.
    var scope: SettingsScope = .app

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @State private var soundsOn = SoundManager.shared.isEnabled

    /// A singleton, so observed rather than owned. The route it reports is the device's,
    /// not this screen's.
    @ObservedObject private var headphones = HeadphoneMonitor.shared

    @ObservedObject private var access = AccessController.shared
    @State private var isPaywallPresented = false
    @State private var isCustomerCenterPresented = false

    /// The interface is dark-only; kept as a constant so the many call sites below
    /// don't each need rewriting.
    private var effectiveColorScheme: ColorScheme { .dark }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rsBackgroundAdaptive(for: effectiveColorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // First: it is the only section that can be in a state the
                        // user needs to act on, and a trial counting down is not
                        // something to make them scroll for.
                        purchaseSection
                            .slideIn(delay: 0.1)

                        // The interface choice belongs to reverse singing, so it
                        // only appears when settings are opened from that game.
                        if scope == .reverseSinging {
                            uiModeSection
                                .slideIn(delay: 0.15)
                        }

                        // Haptic Feedback
                        hapticsSection
                            .slideIn(delay: 0.2)

                        // About Section
                        aboutSection
                            .slideIn(delay: 0.3)

                        // Version Info
                        versionInfo
                            .padding(.top, 8)
                            .fadeIn(delay: 0.4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(Strings.Settings.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.rsTextAdaptive(for: effectiveColorScheme))
                    }
                }
            }
            .onAppear {
                AnalyticsManager.shared.trackSettingsOpened()
                AnalyticsManager.shared.trackScreenViewed(screenName: "SettingsView")
            }
        }
        .purchaseAlerts()
        .sheet(isPresented: $isPaywallPresented) {
            ProPaywallView(source: "settings")
                .preferredColorScheme(.dark)
        }
        // RevenueCat's own screen: receipts, the App Store subscription page,
        // refund requests and the feedback survey. All of it is configured in the
        // dashboard, so the app supplies only the entry point and the reaction to
        // a restore that happened inside it.
        .presentCustomerCenter(
            isPresented: $isCustomerCenterPresented,
            restoreCompleted: { customerInfo in
                access.handleCompletion(customerInfo)
            },
            onDismiss: { isCustomerCenterPresented = false }
        )
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? { .dark }

    // MARK: - UI Mode Section

    private var uiModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Strings.Settings.interface,
                icon: "square.grid.2x2"
            )

            VStack(spacing: 8) {
                ForEach(UIMode.allCases, id: \.self) { mode in
                    uiModeOption(mode)
                }
            }
        }
    }

    private func uiModeOption(_ mode: UIMode) -> some View {
        Button(action: {
            withAnimation(.rsBouncy) {
                viewModel.setUIMode(mode)
            }
            HapticManager.shared.medium()
        }) {
            HStack(spacing: 14) {
                settingsIcon(
                    mode.settingsAssetName,
                    isActive: viewModel.appState.uiMode == mode
                )

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.displayName)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                    Text(mode.description)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                }

                Spacer()

                // Checkmark
                if viewModel.appState.uiMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.rsTurquoise)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .stroke(
                                viewModel.appState.uiMode == mode ?
                                    Color.rsTurquoise.opacity(0.4) :
                                    Color.rsTurquoise.opacity(0.15),
                                lineWidth: viewModel.appState.uiMode == mode ? 1.5 : 1
                            )
                    )
            )
            .cardShadow(viewModel.appState.uiMode == mode ? .elevated : .card)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Haptics Section

    private var hapticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Strings.Settings.preferences,
                icon: "slider.horizontal.3"
            )

            SettingsToggleRow(
                title: Strings.Settings.hapticFeedback,
                subtitle: Strings.Settings.hapticFeedbackDesc,
                isOn: Binding(
                    get: { viewModel.appState.hapticsEnabled },
                    set: { newValue in
                        viewModel.setHapticsEnabled(newValue)
                        if newValue {
                            HapticManager.shared.medium()
                        }
                    }
                )
            ) {
                settingsIcon(
                    "settings-haptics",
                    isActive: viewModel.appState.hapticsEnabled
                )
            }

            soundRow

            headphoneMonitorRow
        }
    }

    /// Interface sound effects, the clapper, the transport clicks, the render chime.
    private var soundRow: some View {
        SettingsToggleRow(
            title: Strings.Settings.soundEffects,
            subtitle: Strings.Settings.soundEffectsDesc,
            isOn: Binding(
                get: { soundsOn },
                set: { newValue in
                    viewModel.setSoundsEnabled(newValue)
                    soundsOn = newValue
                }
            )
        ) {
            settingsIcon("settings-sound", isActive: soundsOn)
        }
    }

    /// Whether the original plays to the performer during a take. Only possible on
    /// headphones, so the row says as much when nothing is plugged in rather than offering a
    /// switch that quietly does nothing.
    private var headphoneMonitorRow: some View {
        SettingsToggleRow(
            title: Strings.Settings.headphoneMonitor,
            subtitle: headphones.isHeadphonesConnected
                ? Strings.Settings.headphoneMonitorDesc
                : Strings.Settings.headphoneMonitorUnavailable,
            isOn: $headphones.isEnabled
        ) {
            settingsIcon("headphones", isActive: headphones.isHeadphonesConnected)
        }
        .onAppear { headphones.refresh() }
    }

    /// Settings illustrations stay colorful when active and become neutral when unavailable.
    private func settingsIcon(_ assetName: String, isActive: Bool = true) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
            .saturation(isActive ? 1 : 0)
            .opacity(isActive ? 1 : 0.45)
            .accessibilityHidden(true)
    }

    // MARK: - Purchase Section

    /// Where the app is bought, and where a purchase is looked after afterwards.
    ///
    /// Its shape follows the state rather than showing every row greyed out: an
    /// owner is offered management, everyone else is offered the purchase. Restore
    /// is the exception and is always there, because the person who needs it is by
    /// definition the person the app currently thinks has not paid.
    @ViewBuilder
    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: Strings.Pro.section, icon: "sparkles")

            VStack(spacing: 8) {
                if access.isEarlyAdopter {
                    // Nothing to sell them and nothing to manage: there is no
                    // transaction behind this, so no Customer Center either.
                    statusCard(
                        assetName: "settings-free-for-life",
                        title: Strings.Pro.EarlyAdopter.settingsTitle,
                        subtitle: Strings.Pro.EarlyAdopter.settingsSubtitle
                    )
                } else if access.isPro {
                    statusCard(
                        assetName: "settings-owned",
                        title: Strings.Pro.ownedTitle,
                        subtitle: Strings.Pro.ownedSubtitle
                    )

                    settingsRow(
                        assetName: "settings-manage-purchase",
                        title: Strings.Pro.manageTitle,
                        subtitle: Strings.Pro.manageSubtitle
                    ) {
                        AnalyticsManager.shared.trackCustomerCenterOpened()
                        isCustomerCenterPresented = true
                    }
                } else {
                    settingsRow(
                        assetName: "settings-unlock",
                        title: Strings.Pro.unlockTitle,
                        subtitle: unlockSubtitle,
                        isProminent: true
                    ) {
                        isPaywallPresented = true
                    }
                }

                if !access.isEarlyAdopter {
                    settingsRow(
                        assetName: "settings-restore-purchase",
                        title: Strings.Pro.restoreTitle,
                        subtitle: Strings.Pro.restoreSubtitle,
                        isBusy: access.isRestoring
                    ) {
                        Task { await access.restore() }
                    }
                }

                #if DEBUG
                if PurchaseConfiguration.isUsingTestStore {
                    Text(Strings.Pro.testStoreWarning)
                        .font(.rsCaptionSmall)
                        .foregroundStyle(Color.rsCaution)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                #endif
            }
        }
    }

    /// The trial counter, restated as a sentence, or the plain offer once it is over.
    private var unlockSubtitle: String {
        guard let days = access.trialDaysRemaining else { return Strings.Pro.unlockSubtitle }
        return days <= 1
            ? Strings.Pro.Trial.oneDayLeft
            : String(format: Strings.Pro.Trial.daysLeft, days)
    }

    /// A row that does something. Shares the geometry of `privacyPolicyButton`.
    private func settingsRow(
        assetName: String,
        title: String,
        subtitle: String,
        isProminent: Bool = false,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            HStack(spacing: 14) {
                settingsIcon(assetName)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                    Text(subtitle)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if isBusy {
                    ProgressView().tint(Color.rsTextSecondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.rsTextTertiary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .stroke(
                                Color.rsTurquoise.opacity(isProminent ? 0.4 : 0.15),
                                lineWidth: isProminent ? 1.5 : 1
                            )
                    )
            )
            .cardShadow(isProminent ? .elevated : .card)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isBusy)
    }

    /// A row that only reports. No chevron, nothing to tap.
    private func statusCard(
        assetName: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 14) {
            settingsIcon(assetName)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.rsBodyLarge)
                    .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                Text(subtitle)
                    .font(.rsCaption)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                        .stroke(Color.rsGood.opacity(0.3), lineWidth: 1)
                )
        )
        .cardShadow(.card)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Strings.Settings.about,
                icon: "info.circle.fill"
            )

            VStack(spacing: 8) {
                privacyPolicyButton
                switzerlandCard
            }
        }
    }

    private var privacyPolicyButton: some View {
        Button(action: openPrivacyPolicy) {
            HStack(spacing: 14) {
                settingsIcon("settings-privacy")

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(Strings.Settings.privacyPolicy)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                    Text(Strings.Settings.privacyPolicyDesc)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                }

                Spacer()

                // External link icon
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.rsTurquoise)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .stroke(Color.rsTurquoise.opacity(0.15), lineWidth: 1)
                    )
            )
            .cardShadow(.card)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var switzerlandCard: some View {
        HStack(spacing: 14) {
            settingsIcon("swiss-flag")

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.Settings.builtInSwitzerland)
                    .font(.rsBodyLarge)
                    .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                Text(Strings.Settings.builtInSwitzerlandDesc)
                    .font(.rsCaption)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                        .stroke(Color.rsTurquoise.opacity(0.15), lineWidth: 1)
                )
        )
        .cardShadow(.card)
    }

    // MARK: - Version Info

    private var versionInfo: some View {
        HStack {
            Spacer()
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text(String(format: Strings.Settings.version, version, build))
                    .font(.rsCaption)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme).opacity(0.5))
            }
            Spacer()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.rsBodySmall)
                .foregroundStyle(Color.rsTurquoise)

            Text(title)
                .font(.rsCaption)
                .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func openPrivacyPolicy() {
        HapticManager.shared.light()
        AnalyticsManager.shared.trackCustomEvent(name: "privacy_policy_opened", parameters: nil)

        if let url = URL(string: "https://falsepeak.ch/privacy") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.rsQuick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @StateObject var viewModel = AudioViewModel()

    SettingsView(viewModel: viewModel)
}

/// A preference: what it is and its switch on one line, the explanation on its own line
/// underneath.
///
/// The explanation used to sit beside the switch, sharing the row's width with the icon and
/// the title. A column narrow enough that "Haptic Feedback" broke onto two lines and the
/// descriptions onto three. Given the full width below the row instead, the titles fit on one
/// line and the copy reads as a sentence.
private struct SettingsToggleRow<Icon: View>: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                icon()

                Text(title)
                    .font(.rsBodyLarge)
                    .foregroundColor(.rsTextPrimary)
                    // Wraps rather than truncating: some of these titles are a good deal
                    // longer in Spanish and Catalan than they are in English.
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                // Labelled for VoiceOver, hidden on screen. The title beside it is the label.
                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .tint(.rsHighlight)
            }

            Text(subtitle)
                .font(.rsCaption)
                .foregroundColor(.rsTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .editorPanel()
    }
}
