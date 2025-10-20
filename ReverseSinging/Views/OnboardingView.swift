//
//  OnboardingView.swift
//  ReverseSinging
//
//  Onboarding tutorial screens
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AudioViewModel
    @State private var currentPage = 0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "waveform.circle.fill",
            title: "Welcome to\nReverse Singing",
            description: "The fun challenge where you sing backwards, then flip it to see how close you got!",
            color: .rsGold
        ),
        OnboardingPage(
            icon: "arrow.triangle.2.circlepath.circle.fill",
            title: "How It Works",
            description: "1. Record or import audio\n2. Reverse it\n3. Sing what you hear\n4. Reverse again & compare!",
            color: .rsGold
        ),
        OnboardingPage(
            icon: "slider.horizontal.3",
            title: "Pro Features",
            description: "Adjust playback speed, loop sections, and save your best attempts. All offline, all private.",
            color: .rsGold
        )
    ]

    var body: some View {
        ZStack {
            Color.rsBackground.ignoresSafeArea()

            VStack(spacing: 40) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.rsGold : Color.rsSecondaryText.opacity(0.4))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.rsSpring, value: currentPage)
                    }
                }
                .padding(.top, 40)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Buttons
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        BigButton(
                            title: "Get Started",
                            icon: "arrow.right.circle.fill",
                            color: .rsGold,
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
                        HStack(spacing: 12) {
                            Button(action: skip) {
                                Text("Skip")
                                    .font(.rsButtonMedium)
                                    .foregroundColor(.rsSecondaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 64)
                            }
                            .transition(.opacity)

                            BigButton(
                                title: "Next",
                                icon: "arrow.right",
                                color: .rsGold,
                                action: nextPage,
                                style: .primary
                            )
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .padding(.bottom, 40)
                .animation(.rsSpring, value: currentPage)
            }
            .padding()
        }
    }

    private func nextPage() {
        withAnimation(.rsSpring) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
        HapticManager.shared.light()
    }

    private func skip() {
        withAnimation(.rsSpring) {
            viewModel.completeOnboarding()
        }
        HapticManager.shared.medium()
    }
}

// MARK: - Onboarding Page

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var iconScale: CGFloat = 0.5
    @State private var iconRotation: Double = -15
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var descriptionOffset: CGFloat = 30
    @State private var descriptionOpacity: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundColor(page.color)
                .shadow(color: page.color.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))

            // Title
            Text(page.title)
                .font(.rsDisplayMedium)
                .foregroundColor(.rsText)
                .multilineTextAlignment(.center)
                .offset(y: titleOffset)
                .opacity(titleOpacity)

            // Description
            Text(page.description)
                .font(.rsBodyLarge)
                .foregroundColor(.rsSecondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .padding(.horizontal, 20)
                .offset(y: descriptionOffset)
                .opacity(descriptionOpacity)

            Spacer()
        }
        .onAppear {
            // Icon animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                iconScale = 1.0
                iconRotation = 0
            }

            // Title animation
            withAnimation(.rsSpring.delay(0.2)) {
                titleOffset = 0
                titleOpacity = 1.0
            }

            // Description animation
            withAnimation(.rsSpring.delay(0.35)) {
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
