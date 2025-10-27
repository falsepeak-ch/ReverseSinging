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

    let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "cassette",
            title: "ReverseSinging",
            description: "hehe, let's make some noise!",
            gradient: .voxxaMicrophone
        ),
        OnboardingPage(
            imageName: "mobile_microphone",
            title: "How It Works",
            description: "Record audio, reverse it, sing what you hear, then flip it again to see how close you got!",
            gradient: .voxxaIconCircle
        )
    ]

    var body: some View {
        ZStack {
            // Black background like Voxxa
            Color.rsBackground.ignoresSafeArea()

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
                    if currentPage == pages.count - 1 {
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

    private func nextPage() {
        withAnimation(.rsSpring) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
        HapticManager.shared.light()
    }
}

// MARK: - Onboarding Page

struct OnboardingPage {
    let imageName: String
    let title: String
    let description: String
    let gradient: LinearGradient
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var descriptionOffset: CGFloat = 20
    @State private var descriptionOpacity: Double = 0

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Large gradient circle with icon (Voxxa-style)
            Image(page.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .gradientCircle(gradient: page.gradient, size: 180)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            VStack(spacing: 16) {
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
                    .lineSpacing(6)
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
