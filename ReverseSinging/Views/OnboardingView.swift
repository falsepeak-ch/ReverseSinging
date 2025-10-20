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
            color: .blue
        ),
        OnboardingPage(
            icon: "arrow.triangle.2.circlepath.circle.fill",
            title: "How It Works",
            description: "1. Record or import audio\n2. Reverse it\n3. Sing what you hear\n4. Reverse again & compare!",
            color: .purple
        ),
        OnboardingPage(
            icon: "slider.horizontal.3",
            title: "Pro Features",
            description: "Adjust playback speed, loop sections, and save your best attempts. All offline, all private.",
            color: .green
        )
    ]

    var body: some View {
        ZStack {
            Color.rsBackground.ignoresSafeArea()

            VStack(spacing: 40) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.rsPrimary : Color.rsSecondaryText)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
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
                            color: .rsPrimary,
                            action: {
                                withAnimation {
                                    viewModel.completeOnboarding()
                                }
                            }
                        )
                    } else {
                        HStack(spacing: 12) {
                            Button(action: skip) {
                                Text("Skip")
                                    .font(.rsButtonMedium)
                                    .foregroundColor(.rsSecondaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 64)
                            }

                            BigButton(
                                title: "Next",
                                icon: "arrow.right",
                                color: .rsPrimary,
                                action: nextPage
                            )
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }

    private func nextPage() {
        withAnimation {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
    }

    private func skip() {
        withAnimation {
            viewModel.completeOnboarding()
        }
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

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundColor(page.color)
                .shadow(color: page.color.opacity(0.3), radius: 20, x: 0, y: 10)

            // Title
            Text(page.title)
                .font(.rsDisplayMedium)
                .foregroundColor(.rsText)
                .multilineTextAlignment(.center)

            // Description
            Text(page.description)
                .font(.rsBodyLarge)
                .foregroundColor(.rsSecondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(viewModel: AudioViewModel())
}
