//
//  SettingsView.swift
//  ReverseSinging
//
//  Premium settings page matching SessionList aesthetic
//

import SwiftUI
import RevenueCatUI
import DubAudio

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    @Environment(\.dismiss) var dismiss

    /// A singleton, so observed rather than owned. The route it reports is the device's,
    /// not this screen's.
    @ObservedObject private var headphones = HeadphoneMonitor.shared

    /// The front camera that films a dub take. A singleton like the others, so the switch
    /// here and the key in the record HUD are the same switch.
    @ObservedObject private var booth = BoothCamPreference.shared

    /// The interface is dark-only; kept as a constant so the many call sites below
    /// don't each need rewriting.
    private var effectiveColorScheme: ColorScheme { .dark }

    /// - Parameter scope: defaults to the narrow set; a game screen opts in to its own options.
    init(app: AppViewModel, scope: SettingsScope = .app) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(app: app, scope: scope))
    }

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

                        if viewModel.showsInterfaceSection {
                            uiModeSection
                                .slideIn(delay: 0.15)
                        }

                        // Haptic Feedback
                        hapticsSection
                            .slideIn(delay: 0.2)

                        // The camera gets its own section rather than a fourth row above:
                        // turning one on is not a decision of the same weight as a click
                        // sound, and it is the only thing in here that writes video.
                        boothSection
                            .slideIn(delay: 0.25)

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
            .onAppear { viewModel.onAppear() }
        }
        .purchaseAlerts()
        .sheet(isPresented: $viewModel.isPaywallPresented) {
            ProPaywallView(source: "settings")
                .preferredColorScheme(.dark)
        }
        // RevenueCat's own screen: receipts, the App Store subscription page,
        // refund requests and the feedback survey. All of it is configured in the
        // dashboard, so the app supplies only the entry point and the reaction to
        // a restore that happened inside it.
        .presentCustomerCenter(
            isPresented: $viewModel.isCustomerCenterPresented,
            restoreCompleted: { customerInfo in
                viewModel.customerCenterDidRestore(customerInfo)
            },
            onDismiss: { viewModel.isCustomerCenterPresented = false }
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
                    isActive: viewModel.uiMode == mode
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
                if viewModel.uiMode == mode {
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
                                viewModel.uiMode == mode ?
                                    Color.rsTurquoise.opacity(0.4) :
                                    Color.rsTurquoise.opacity(0.15),
                                lineWidth: viewModel.uiMode == mode ? 1.5 : 1
                            )
                    )
            )
            .cardShadow(viewModel.uiMode == mode ? .elevated : .card)
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
                    get: { viewModel.hapticsEnabled },
                    set: { viewModel.setHapticsEnabled($0) }
                )
            ) {
                settingsIcon(
                    "settings-haptics",
                    isActive: viewModel.hapticsEnabled
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
                get: { viewModel.soundsEnabled },
                set: { viewModel.setSoundsEnabled($0) }
            )
        ) {
            settingsIcon("settings-sound", isActive: viewModel.soundsEnabled)
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

    // MARK: - Booth Cam Section

    private var boothSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: Strings.Booth.settingsSection, icon: "video.fill")

            SettingsToggleRow(
                title: Strings.Booth.settingsTitle,
                subtitle: viewModel.isBoothDenied ? Strings.Booth.settingsDenied : Strings.Booth.settingsDesc,
                isOn: Binding(
                    get: { booth.isEnabled },
                    set: { viewModel.setBoothEnabled($0) }
                )
            ) {
                boothIcon
            }
            .disabled(viewModel.isBoothDenied)
            .opacity(viewModel.isBoothDenied ? 0.55 : 1)

            // Only meaningful once there is a monitor to mirror.
            if booth.isEnabled {
                SettingsToggleRow(
                    title: Strings.Booth.mirrorTitle,
                    subtitle: Strings.Booth.mirrorDesc,
                    isOn: $booth.mirrorsPreview
                ) {
                    mirrorIcon
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Shown only when there is something to account for. An empty storage row is
            // just a reminder of a cost nobody has paid yet.
            if viewModel.boothUsage.bytes > 0 {
                boothFootagePanel
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: booth.isEnabled)
        .animation(.easeInOut(duration: 0.2), value: viewModel.boothUsage.bytes)
        .onAppear { viewModel.refreshBoothUsage() }
        .alert(Strings.Booth.deleteAll, isPresented: $viewModel.isConfirmingBoothDelete) {
            Button(Strings.Booth.deleteAllConfirm, role: .destructive) { viewModel.deleteBoothFootage() }
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Booth.deleteAllMessage)
        }
    }

    /// What the camera has cost so far, and the one way to get it back.
    private var boothFootagePanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(Strings.Booth.footage)
                    .editorLabelStyle()

                Rectangle()
                    .fill(Color.rsStroke)
                    .frame(height: EditorMetrics.hairline)

                Text(
                    String(
                        format: Strings.Booth.footageUsage,
                        ByteCountFormatter.string(fromByteCount: viewModel.boothUsage.bytes, countStyle: .file),
                        viewModel.boothUsage.packs
                    )
                )
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            EditorRule()

            Button {
                HapticManager.shared.light()
                viewModel.isConfirmingBoothDelete = true
            } label: {
                Text(Strings.Booth.deleteAll)
                    .font(.rsBodyMedium)
                    .foregroundColor(.rsRecord)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .editorPanel()
    }

    private var boothIcon: some View {
        settingsIcon("settings-booth-cam", isActive: booth.isEnabled && !viewModel.isBoothDenied)
    }

    private var mirrorIcon: some View {
        settingsIcon("settings-mirror-preview", isActive: booth.mirrorsPreview)
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
                if viewModel.isEarlyAdopter {
                    // Nothing to sell them and nothing to manage: there is no
                    // transaction behind this, so no Customer Center either.
                    statusCard(
                        assetName: "settings-free-for-life",
                        title: Strings.Pro.EarlyAdopter.settingsTitle,
                        subtitle: Strings.Pro.EarlyAdopter.settingsSubtitle
                    )
                } else if viewModel.isPro {
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
                        viewModel.openCustomerCenter()
                    }
                } else {
                    settingsRow(
                        assetName: "settings-unlock",
                        title: Strings.Pro.unlockTitle,
                        subtitle: viewModel.unlockSubtitle,
                        isProminent: true
                    ) {
                        viewModel.showPaywall()
                    }
                }

                if !viewModel.isEarlyAdopter {
                    settingsRow(
                        assetName: "settings-restore-purchase",
                        title: Strings.Pro.restoreTitle,
                        subtitle: Strings.Pro.restoreSubtitle,
                        isBusy: viewModel.isRestoring
                    ) {
                        viewModel.restore()
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
        Button(action: viewModel.openPrivacyPolicy) {
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
            if let versionText = viewModel.versionText {
                Text(versionText)
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
}

// MARK: - Preview

#Preview {
    SettingsView(app: AppViewModel())
}
