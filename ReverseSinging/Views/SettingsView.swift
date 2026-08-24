//
//  SettingsView.swift
//  ReverseSinging
//
//  Premium settings page matching SessionList aesthetic
//

import SwiftUI

/// Which settings a presentation is allowed to show.
///
/// The menu owns nothing but the app itself, so opening settings from there must
/// not offer choices that belong to one game — the Simple/Complex interface is a
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

    /// A singleton, so observed rather than owned — the route it reports is the device's,
    /// not this screen's.
    @ObservedObject private var headphones = HeadphoneMonitor.shared

    /// The interface is dark-only; kept as a constant so the many call sites below
    /// don't each need rewriting.
    private var effectiveColorScheme: ColorScheme { .dark }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rsBackgroundAdaptive(for: effectiveColorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
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
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: viewModel.appState.uiMode == mode ?
                                    [Color.rsTurquoise, Color.rsTurquoise.opacity(0.8)] :
                                    [Color.rsSecondaryTextAdaptive(for: effectiveColorScheme).opacity(0.15), Color.rsSecondaryTextAdaptive(for: effectiveColorScheme).opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: mode.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            viewModel.appState.uiMode == mode ?
                                LinearGradient(colors: [.white, .white], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.rsSecondaryTextAdaptive(for: effectiveColorScheme), Color.rsSecondaryTextAdaptive(for: effectiveColorScheme)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

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

            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: viewModel.appState.hapticsEnabled ?
                                    [Color.rsTurquoise, Color.rsTurquoise.opacity(0.8)] :
                                    [Color.rsSecondaryTextAdaptive(for: effectiveColorScheme).opacity(0.15), Color.rsSecondaryTextAdaptive(for: effectiveColorScheme).opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            viewModel.appState.hapticsEnabled ?
                                LinearGradient(colors: [.white, .white], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.rsSecondaryTextAdaptive(for: effectiveColorScheme), Color.rsSecondaryTextAdaptive(for: effectiveColorScheme)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(Strings.Settings.hapticFeedback)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                    Text(Strings.Settings.hapticFeedbackDesc)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                }

                Spacer()

                // Toggle
                Toggle("", isOn: Binding(
                    get: { viewModel.appState.hapticsEnabled },
                    set: { newValue in
                        viewModel.setHapticsEnabled(newValue)
                        if newValue {
                            HapticManager.shared.medium()
                        }
                    }
                ))
                .tint(.rsHighlight)
            }
            .padding(16)
            .editorPanel()

            soundRow

            headphoneMonitorRow
        }
    }

    /// Interface sound effects — the clapper, the transport clicks, the render chime.
    private var soundRow: some View {
        HStack(spacing: 14) {
            Image(systemName: soundsOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(soundsOn ? .rsTextPrimary : .rsTextTertiary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.rsSurface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.Settings.soundEffects)
                    .font(.rsBodyLarge)
                    .foregroundColor(.rsTextPrimary)

                Text(Strings.Settings.soundEffectsDesc)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextTertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { soundsOn },
                set: { newValue in
                    viewModel.setSoundsEnabled(newValue)
                    soundsOn = newValue
                }
            ))
            .tint(.rsHighlight)
        }
        .padding(16)
        .editorPanel()
    }

    /// Whether the original plays to the performer during a take. Only possible on
    /// headphones, so the row says as much when nothing is plugged in rather than offering a
    /// switch that quietly does nothing.
    private var headphoneMonitorRow: some View {
        HStack(spacing: 14) {
            Image(systemName: headphones.isHeadphonesConnected ? "headphones" : "headphones.slash")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(headphones.isHeadphonesConnected ? .rsTextPrimary : .rsTextTertiary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.rsSurface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.Settings.headphoneMonitor)
                    .font(.rsBodyLarge)
                    .foregroundColor(.rsTextPrimary)

                Text(headphones.isHeadphonesConnected
                     ? Strings.Settings.headphoneMonitorDesc
                     : Strings.Settings.headphoneMonitorUnavailable)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextTertiary)
            }

            Spacer()

            Toggle("", isOn: $headphones.isEnabled)
                .tint(.rsHighlight)
        }
        .padding(16)
        .editorPanel()
        .onAppear { headphones.refresh() }
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
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.rsTurquoise, Color.rsTurquoise.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(Strings.Settings.privacyPolicy)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                    Text("Read our privacy policy")
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
            // Flag circle
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.rsSurface2)
                    .frame(width: 44, height: 44)

                Text("🇨🇭")
                    .font(.system(size: 24))
            }

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
                Text("Version \(version) (\(build))")
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
