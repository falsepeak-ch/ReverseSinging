//
//  SettingsView.swift
//  ReverseSinging
//
//  Settings page with theme, haptics, privacy policy, and app info
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Appearance Section
                    settingsSection(
                        title: "Appearance",
                        icon: "paintbrush.fill",
                        content: {
                            themePicker
                        }
                    )

                    // Preferences Section
                    settingsSection(
                        title: "Preferences",
                        icon: "slider.horizontal.3",
                        content: {
                            hapticsToggle
                        }
                    )

                    // About Section
                    settingsSection(
                        title: "About",
                        icon: "info.circle.fill",
                        content: {
                            VStack(spacing: 12) {
                                privacyPolicyRow
                                switzerlandRow
                            }
                        }
                    )

                    // Version Info
                    versionInfo
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.rsBackgroundAdaptive(for: colorScheme))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.rsHeadingSmall)
                            .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                    }
                }
            }
            .onAppear {
                AnalyticsManager.shared.trackSettingsOpened()
                AnalyticsManager.shared.trackScreenViewed(screenName: "SettingsView")
            }
        }
    }

    // MARK: - Theme Picker

    private var themePicker: some View {
        HStack(spacing: 0) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Button(action: {
                    viewModel.setThemeMode(mode)
                    HapticManager.shared.light()
                }) {
                    Text(mode.rawValue)
                        .font(.rsBodyMedium)
                        .foregroundColor(viewModel.appState.themeMode == mode ?
                                       Color.rsTextOnTurquoise : Color.rsTextAdaptive(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.appState.themeMode == mode ?
                                Color.rsTurquoise : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.rsCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.rsTurquoise.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Haptics Toggle

    private var hapticsToggle: some View {
        HStack {
            Image(systemName: "waveform")
                .font(.rsHeadingSmall)
                .foregroundColor(.rsTurquoise)
                .frame(width: 32)

            Text("Haptic Feedback")
                .font(.rsBodyMedium)
                .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.appState.hapticsEnabled },
                set: { newValue in
                    viewModel.setHapticsEnabled(newValue)
                    if newValue {
                        HapticManager.shared.light()
                    }
                }
            ))
            .tint(.rsTurquoise)
        }
        .padding(16)
        .background(Color.rsCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .cardShadow(.card)
    }

    // MARK: - Privacy Policy Row

    private var privacyPolicyRow: some View {
        Button(action: openPrivacyPolicy) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTurquoise)
                    .frame(width: 32)

                Text("Privacy Policy")
                    .font(.rsBodyMedium)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.rsBodySmall)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
            }
            .padding(16)
            .background(Color.rsCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .cardShadow(.card)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Switzerland Row

    private var switzerlandRow: some View {
        HStack {
            Text("🇨🇭")
                .font(.system(size: 28))
                .frame(width: 32)

            Text("Built in Switzerland")
                .font(.rsBodyMedium)
                .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

            Spacer()
        }
        .padding(16)
        .background(Color.rsCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .cardShadow(.card)
    }

    // MARK: - Version Info

    private var versionInfo: some View {
        VStack(spacing: 4) {
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(build))")
                    .font(.rsCaption)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
            }
        }
    }

    // MARK: - Settings Section Builder

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.rsBodyMedium)
                    .foregroundColor(.rsTurquoise)

                Text(title)
                    .font(.rsHeadingSmall)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
            }

            // Section Content
            content()
        }
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

// MARK: - Preview

#Preview {
    @Previewable @StateObject var viewModel = AudioViewModel()

    SettingsView(viewModel: viewModel)
}
