//
//  SettingsView.swift
//  ReverseSinging
//
//  Premium settings page with enhanced design
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background
            Color.rsBackgroundAdaptive(for: colorScheme)
                .ignoresSafeArea()

            // Content
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerView
                        .padding(.top, 20)

                    // Theme Selector
                    themeSection

                    // Haptic Feedback Toggle
                    hapticsSection

                    // About Section
                    aboutSection

                    // Version Info
                    versionInfo
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            AnalyticsManager.shared.trackSettingsOpened()
            AnalyticsManager.shared.trackScreenViewed(screenName: "SettingsView")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Strings.Settings.title)
                    .font(.rsHeadingLarge)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                Text(Strings.Settings.subtitle)
                    .font(.rsBodySmall)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
            }

            Spacer()

            // Close button
            Button(action: {
                HapticManager.shared.light()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
            }
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: Strings.Settings.appearance,
                icon: "paintbrush.fill"
            )

            VStack(spacing: 12) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    themeOption(mode)
                }
            }
        }
    }

    private func themeOption(_ mode: ThemeMode) -> some View {
        Button(action: {
            viewModel.setThemeMode(mode)
            HapticManager.shared.medium()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(viewModel.appState.themeMode == mode ?
                              Color.rsTurquoise.opacity(0.2) :
                              Color.rsSecondaryTextAdaptive(for: colorScheme).opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: iconForMode(mode))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(viewModel.appState.themeMode == mode ?
                                       .rsTurquoise :
                                       Color.rsSecondaryTextAdaptive(for: colorScheme))
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                    Text(descriptionForMode(mode))
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                }

                Spacer()

                // Checkmark
                if viewModel.appState.themeMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.rsTurquoise)
                }
            }
            .padding(20)
            .background(Color.rsCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .cardShadow(viewModel.appState.themeMode == mode ? .elevated : .card)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(viewModel.appState.themeMode == mode ?
                           Color.rsTurquoise.opacity(0.5) : Color.clear,
                           lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconForMode(_ mode: ThemeMode) -> String {
        switch mode {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    private func descriptionForMode(_ mode: ThemeMode) -> String {
        switch mode {
        case .system:
            return Strings.Settings.themeSystemDesc
        case .light:
            return Strings.Settings.themeLightDesc
        case .dark:
            return Strings.Settings.themeDarkDesc
        }
    }

    // MARK: - Haptics Section

    private var hapticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: Strings.Settings.preferences,
                icon: "slider.horizontal.3"
            )

            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(viewModel.appState.hapticsEnabled ?
                              Color.rsTurquoise.opacity(0.2) :
                              Color.rsSecondaryTextAdaptive(for: colorScheme).opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(viewModel.appState.hapticsEnabled ?
                                       .rsTurquoise :
                                       Color.rsSecondaryTextAdaptive(for: colorScheme))
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.Settings.hapticFeedback)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                    Text(Strings.Settings.hapticFeedbackDesc)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
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
                .tint(.rsTurquoise)
            }
            .padding(20)
            .background(Color.rsCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .cardShadow(.card)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: Strings.Settings.about,
                icon: "info.circle.fill"
            )

            VStack(spacing: 12) {
                privacyPolicyButton
                switzerlandCard
            }
        }
    }

    private var privacyPolicyButton: some View {
        Button(action: openPrivacyPolicy) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.rsTurquoise.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.rsTurquoise)
                }

                // Text
                Text(Strings.Settings.privacyPolicy)
                    .font(.rsBodyLarge)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                Spacer()

                // External link icon
                Image(systemName: "arrow.up.right")
                    .font(.rsBodyMedium)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
            }
            .padding(20)
            .background(Color.rsCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .cardShadow(.card)
        }
        .buttonStyle(.plain)
    }

    private var switzerlandCard: some View {
        HStack(spacing: 16) {
            // Flag
            Text("🇨🇭")
                .font(.system(size: 40))
                .frame(width: 48, height: 48)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.Settings.builtInSwitzerland)
                    .font(.rsBodyLarge)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                Text(Strings.Settings.builtInSwitzerlandDesc)
                    .font(.rsCaption)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
            }

            Spacer()
        }
        .padding(20)
        .background(Color.rsCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme).opacity(0.6))
            }
            Spacer()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.rsBodyMedium)
                .foregroundColor(.rsTurquoise)

            Text(title)
                .font(.rsHeadingSmall)
                .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                .textCase(.uppercase)
                .tracking(1)
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
