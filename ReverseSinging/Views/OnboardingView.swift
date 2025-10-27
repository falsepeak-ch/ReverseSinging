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
    @Environment(\.colorScheme) var colorScheme

    let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "microphone",
            title: "Welcome to Reverso",
            description: "We need microphone access to record and reverse your audio. Let's get started!",
            matteColor: Color.rsCream  // Cream with teal blend
        ),
        OnboardingPage(
            imageName: "radio",
            title: "How It Works",
            description: "Record audio, reverse it, sing what you hear, then flip it again to see how close you got!",
            matteColor: Color.rsCharcoal  // Charcoal with red blend
        )
    ]

    // MARK: - Computed Properties for Single Button State

    private var buttonTitle: String {
        if permissionGranted {
            return "Continue"
        } else if permissionDenied {
            return "Open Settings"
        } else {
            return "Allow Microphone Use"
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
            return nextPage
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
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .disabled(currentPage == 0 && !permissionGranted)

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
                    if currentPage == 0 {
                        // Page 1: Welcome - single dynamic permission button
                        BigButton(
                            title: buttonTitle,
                            icon: buttonIcon,
                            color: buttonColor,
                            action: buttonAction,
                            style: .primary
                        )
                    } else if currentPage == pages.count - 1 {
                        // Last page: Show final button
                        BigButton(
                            title: "yes, let's record!",
                            icon: "arrow.right",
                            color: .rsTurquoise,
                            action: {
                                withAnimation(.rsSpring) {
                                    viewModel.completeOnboarding()
                                }
                            },
                            style: .primary
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    } else {
                        // Middle pages: Just continue
                        BigButton(
                            title: "continue",
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

    private func requestMicrophonePermission() {
        guard !permissionRequested else { return }

        permissionRequested = true
        HapticManager.shared.light()

        // Request permission with callback
        viewModel.requestPermission { [self] granted in
            withAnimation(.rsSpring) {
                self.permissionGranted = granted
                self.permissionDenied = !granted
            }

            if granted {
                HapticManager.shared.success()
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
        VStack(spacing: 40) {
            Spacer()

            // Large illustration with smaller matte circle background
            Image(page.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 280, height: 280)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            VStack(spacing: 16) {
                // Title
                Text(page.title)
                    .font(.custom("Eugello", size: 36))
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                // Description
                Text(page.description)
                    .font(.rsBodyLarge)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .offset(y: descriptionOffset)
                    .opacity(descriptionOpacity)
            }

            Spacer()
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
}

// MARK: - Preview

#Preview {
    OnboardingView(viewModel: AudioViewModel())
}
