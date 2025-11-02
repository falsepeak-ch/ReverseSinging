//
//  SettingsView.swift
//  ReverseSinging
//
//  Premium settings page matching SessionList aesthetic
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme

    // Computed effective color scheme based on theme mode
    private var effectiveColorScheme: ColorScheme {
        switch viewModel.appState.themeMode {
        case .system:
            return systemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rsBackgroundAdaptive(for: effectiveColorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Theme Selector
                        themeSection
                            .slideIn(delay: 0.1)

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

    private var preferredColorScheme: ColorScheme? {
        switch viewModel.appState.themeMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Strings.Settings.appearance,
                icon: "paintbrush.fill"
            )

            VStack(spacing: 8) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    themeOption(mode)
                }
            }
        }
    }

    private func themeOption(_ mode: ThemeMode) -> some View {
        Button(action: {
            withAnimation(.rsBouncy) {
                viewModel.setThemeMode(mode)
            }
            HapticManager.shared.medium()
        }) {
            HStack(spacing: 14) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: viewModel.appState.themeMode == mode ?
                                    [Color.rsTurquoise, Color.rsTurquoise.opacity(0.8)] :
                                    [Color.rsSecondaryTextAdaptive(for: effectiveColorScheme).opacity(0.15), Color.rsSecondaryTextAdaptive(for: effectiveColorScheme).opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: iconForMode(mode))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            viewModel.appState.themeMode == mode ?
                                LinearGradient(colors: [.white, .white], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.rsSecondaryTextAdaptive(for: effectiveColorScheme), Color.rsSecondaryTextAdaptive(for: effectiveColorScheme)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.rawValue)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                    Text(descriptionForMode(mode))
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                }

                Spacer()

                // Checkmark
                if viewModel.appState.themeMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.rsTurquoise)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                viewModel.appState.themeMode == mode ?
                                    Color.rsTurquoise.opacity(0.4) :
                                    Color.rsTurquoise.opacity(0.15),
                                lineWidth: viewModel.appState.themeMode == mode ? 1.5 : 1
                            )
                    )
            )
            .cardShadow(viewModel.appState.themeMode == mode ? .elevated : .card)
        }
        .buttonStyle(ScaleButtonStyle())
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
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Strings.Settings.preferences,
                icon: "slider.horizontal.3"
            )

            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
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
                .tint(.rsTurquoise)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.rsTurquoise.opacity(0.15), lineWidth: 1)
                    )
            )
            .cardShadow(.card)
        }
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
                    Circle()
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                Circle()
                    .fill(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme).opacity(0.1))
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
