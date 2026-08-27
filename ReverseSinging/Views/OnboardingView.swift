//
//  OnboardingView.swift
//  ReverseSinging
//
//  Voxxa-inspired onboarding with gradient icons
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AudioViewModel
    @State private var currentPage = 0
    @State private var permissionGranted = false
    @State private var permissionRequested = false
    @State private var permissionDenied = false
    @State private var selectedUIMode: UIMode = .simple
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "microphone",
            title: Strings.Onboarding.welcomeTitle,
            description: Strings.Onboarding.welcomeMessage,
            matteColor: Color.rsSurface1
        ),
        OnboardingPage(
            imageName: "radio",
            title: Strings.Onboarding.howItWorksTitle,
            description: Strings.Onboarding.howItWorksMessage,
            matteColor: Color.rsSurface1
        ),
        // The second game gets its own page: dubbing is nothing like reverse
        // singing, and the "bring your own files" part is better said here than
        // discovered at the content gate.
        OnboardingPage(
            imageName: "clapperboard",
            title: Strings.Onboarding.dubTitle,
            description: Strings.Onboarding.dubMessage,
            matteColor: Color.rsSurface1
        ),
        OnboardingPage(
            imageName: "microphone",  // Placeholder, won't be used
            title: Strings.Onboarding.uiPreferenceTitle,
            description: Strings.Onboarding.uiPreferenceMessage,
            matteColor: Color.rsSurface1
        ),
        // The permission ask comes last, once both games have been shown: by
        // now "we need the microphone" reads as the obvious next step rather
        // than a toll gate in front of an app the user hasn't seen yet.
        OnboardingPage(
            imageName: "studio-mic-boom",
            title: Strings.Onboarding.microphoneTitle,
            description: Strings.Onboarding.microphoneMessage,
            matteColor: Color.rsSurface1
        )
    ]

    /// The interface picker draws itself; every other page is a plain illustration.
    private var uiPreferenceIndex: Int { pages.count - 2 }
    /// The microphone ask, and the end of onboarding.
    private var permissionIndex: Int { pages.count - 1 }

    // MARK: - Computed Properties for Single Button State

    /// The default reads "Continue", not "Allow": this button opens the system
    /// prompt, it is not the grant itself, and promising a permission the page
    /// cannot give is the kind of thing that reads as a dark pattern. The mic
    /// icon below is what carries the warning that a prompt is coming.
    private var buttonTitle: String {
        if permissionGranted {
            return Strings.Onboarding.buttonLetsRecord
        } else if permissionDenied {
            return Strings.Onboarding.buttonOpenSettings
        } else {
            return Strings.Onboarding.buttonMicrophoneContinue
        }
    }

    private var buttonIcon: String {
        if permissionGranted {
            return "arrow.right"
        } else if permissionDenied {
            return "gearshape.fill"
        } else {
            return "mic.fill"
        }
    }

    private var buttonColor: Color {
        if permissionGranted {
            return .rsTurquoise
        } else if permissionDenied {
            return .rsWarning
        } else {
            return .rsTurquoise
        }
    }

    private var buttonAction: () -> Void {
        if permissionGranted {
            return finishOnboarding
        } else if permissionDenied {
            return openSettings
        } else {
            return requestMicrophonePermission
        }
    }

    var body: some View {
        ZStack {
            // Adaptive background (dark/light mode)
            Color.rsBackgroundAdaptive(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 32) {
                // Back button placeholder (like Voxxa has in header)
                HStack {
                    Spacer()
                }
                .frame(height: 44)
                .padding(.top, 8)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        if index == uiPreferenceIndex {
                            // UI Preference page with custom layout
                            uiPreferencePage
                                .tag(index)
                        } else {
                            OnboardingPageView(page: page)
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: index == currentPage ? 32 : 8, height: 8)
                            .animation(.rsSpring, value: currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Buttons
                VStack(spacing: 16) {
                    if currentPage == permissionIndex {
                        // Last page: the microphone ask, as a single dynamic button
                        BigButton(
                            title: buttonTitle,
                            icon: buttonIcon,
                            color: buttonColor,
                            action: buttonAction,
                            style: .primary
                        )

                        // A denial shouldn't trap anyone on the last page — the
                        // games ask again themselves when a recording is due.
                        if permissionDenied {
                            Button(action: finishOnboarding) {
                                Text(Strings.Onboarding.buttonContinueWithout)
                                    .font(.rsButtonMedium)
                                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                            }
                        }
                    } else {
                        // Every other page: just continue
                        BigButton(
                            title: Strings.Onboarding.buttonContinueLowercase,
                            icon: "arrow.right",
                            color: .rsTurquoise,
                            action: nextPage,
                            style: .primary
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .animation(.rsSpring, value: currentPage)
            }
        }
        .onAppear {
            // Track onboarding started
            AnalyticsManager.shared.trackOnboardingStarted()
        }
        // Coming back from Settings with access granted should move the button
        // on, rather than leaving the user staring at "Open Settings" again.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, permissionDenied else { return }
            viewModel.checkPermissionStatus()
            guard viewModel.hasRecordingPermission else { return }
            withAnimation(.rsSpring) {
                permissionGranted = true
                permissionDenied = false
            }
        }
    }

    // MARK: - UI Preference Page

    private var uiPreferencePage: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Top spacing
                    Spacer()
                        .frame(height: 40)

                    // Title
                    Text(Strings.Onboarding.uiPreferenceTitle)
                        .font(.rsDisplayLarge)
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Description
                    Text(Strings.Onboarding.uiPreferenceMessage)
                        .font(.rsBodyLarge)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                    // UI Mode Cards
                    HStack(spacing: 16) {
                        UIPreferenceCard(
                            mode: .simple,
                            isSelected: selectedUIMode == .simple,
                            action: {
                                withAnimation(.rsSpring) {
                                    selectedUIMode = .simple
                                }
                                viewModel.setUIMode(.simple)
                                HapticManager.shared.light()
                            }
                        )

                        UIPreferenceCard(
                            mode: .complex,
                            isSelected: selectedUIMode == .complex,
                            action: {
                                withAnimation(.rsSpring) {
                                    selectedUIMode = .complex
                                }
                                viewModel.setUIMode(.complex)
                                HapticManager.shared.light()
                            }
                        )
                    }
                    .padding(.horizontal, 24)

                    // Bottom spacing
                    Spacer()
                        .frame(height: 40)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
    }

    // MARK: - Navigation

    private func nextPage() {
        withAnimation(.rsSpring) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
        HapticManager.shared.light()
    }

    private func finishOnboarding() {
        withAnimation(.rsSpring) {
            // Belt and braces: the picker already saved this on selection, but
            // nobody has to touch it, so the default still needs writing.
            viewModel.setUIMode(selectedUIMode)
            AnalyticsManager.shared.trackOnboardingCompleted()
            viewModel.completeOnboarding()
        }
    }

    private func requestMicrophonePermission() {
        guard !permissionRequested else { return }

        permissionRequested = true
        HapticManager.shared.light()

        // Track permission requested
        AnalyticsManager.shared.trackPermissionRequested()

        // Request permission with callback
        viewModel.requestPermission { [self] granted in
            withAnimation(.rsSpring) {
                self.permissionGranted = granted
                self.permissionDenied = !granted
            }

            if granted {
                HapticManager.shared.success()
                // Granted on the last page — drop straight into the app.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.finishOnboarding()
                }
            } else {
                HapticManager.shared.error()
            }
        }
    }

    private func openSettings() {
        HapticManager.shared.light()

        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Onboarding Page

struct OnboardingPage {
    let imageName: String
    let title: String
    let description: String
    let matteColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Environment(\.colorScheme) var colorScheme
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var descriptionOffset: CGFloat = 20
    @State private var descriptionOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: adaptiveSpacing(for: geometry.size.height)) {
                    // Top spacing
                    Spacer()
                        .frame(height: topSpacing(for: geometry.size.height))

                    // Large illustration with adaptive size
                    Image(page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize(for: geometry.size), height: imageSize(for: geometry.size))
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)

                    VStack(spacing: 16) {
                        // Title
                        Text(page.title)
                            .font(.rsDisplay(titleSize(for: geometry.size.height), relativeTo: .largeTitle))
                            .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, horizontalPadding(for: geometry.size.width))
                            .offset(y: titleOffset)
                            .opacity(titleOpacity)

                        // Description
                        Text(page.description)
                            .font(.rsBodyLarge)
                            .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, horizontalPadding(for: geometry.size.width))
                            .offset(y: descriptionOffset)
                            .opacity(descriptionOpacity)
                    }

                    // Bottom spacing
                    Spacer()
                        .frame(height: bottomSpacing(for: geometry.size.height))
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .onAppear {
            // Icon animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // Title animation
            withAnimation(.rsSpring.delay(0.15)) {
                titleOffset = 0
                titleOpacity = 1.0
            }

            // Description animation
            withAnimation(.rsSpring.delay(0.25)) {
                descriptionOffset = 0
                descriptionOpacity = 1.0
            }
        }
    }

    // MARK: - Dynamic Layout Helpers (Percentage-Based)

    private func imageSize(for size: CGSize) -> CGFloat {
        // Dynamic sizing: 30-42% of height OR 52% of width, whichever is smaller
        // Works for any screen size and aspect ratio
        let isLandscape = size.width > size.height

        let heightBased = size.height * (isLandscape ? 0.42 : 0.35)
        let widthBased = size.width * 0.52

        let dynamicSize = min(heightBased, widthBased)

        // Cap between 140pt (tiny windows) and 450pt (iPad Pro)
        return min(450, max(140, dynamicSize))
    }

    private func titleSize(for height: CGFloat) -> CGFloat {
        // Dynamic: 4-5% of screen height
        let dynamicSize = height * 0.045
        // Cap between 20pt and 48pt
        return min(48, max(20, dynamicSize))
    }

    private func adaptiveSpacing(for height: CGFloat) -> CGFloat {
        // Dynamic: 3% of screen height for content spacing
        let spacing = height * 0.03
        return min(40, max(12, spacing))
    }

    private func topSpacing(for height: CGFloat) -> CGFloat {
        // Dynamic: 6-8% of screen height for top padding
        let spacing = height * 0.07
        return min(80, max(16, spacing))
    }

    private func bottomSpacing(for height: CGFloat) -> CGFloat {
        // Dynamic: 6-8% of screen height for bottom padding
        let spacing = height * 0.07
        return min(80, max(16, spacing))
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        // Dynamic: 6-8% of screen width
        let padding = width * 0.07
        return min(60, max(20, padding))
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(viewModel: AudioViewModel())
}
