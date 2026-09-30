//
//  OnboardingView.swift
//  ReverseSinging
//
//  The first-run pages, and the buttons under them
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    init(app: AppViewModel) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(app: app))
    }

    var body: some View {
        ZStack {
            // Adaptive background (dark/light mode)
            Color.rsBackgroundAdaptive(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 24) {
                #if os(iOS)
                TabView(selection: $viewModel.currentPage) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                #else
                // The Mac has no swipeable pages: one page at a time, moved by the button below.
                OnboardingPageView(page: viewModel.pages[viewModel.currentPage])
                    .id(viewModel.currentPage)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(.rsSmooth, value: viewModel.currentPage)
                    .frame(maxHeight: .infinity)
                #endif

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == viewModel.currentPage ? LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: index == viewModel.currentPage ? 32 : 8, height: 8)
                            .animation(.rsSpring, value: viewModel.currentPage)
                    }
                }

                // Buttons
                VStack(spacing: 8) {
                    BigButton(
                        title: viewModel.offersPro ? Strings.Onboarding.proBuy : Strings.Onboarding.buttonContinueLowercase,
                        icon: viewModel.offersPro ? "lock.open.fill" : "arrow.right",
                        color: .rsTurquoise,
                        action: viewModel.primaryTapped,
                        style: .primary
                    )

                    // Always laid out, so the pages above do not jump when it arrives on the
                    // last one.
                    Button(action: viewModel.finishOnboarding) {
                        Text(Strings.Onboarding.proSkip)
                            .font(.rsButtonMedium)
                            .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .contentShape(Rectangle())
                    }
                    .opacity(viewModel.offersPro ? 1 : 0)
                    .allowsHitTesting(viewModel.offersPro)
                    .accessibilityHidden(!viewModel.offersPro)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .animation(.rsSpring, value: viewModel.offersPro)
            }
        }
        .sheet(isPresented: $viewModel.isPaywallPresented) {
            ProPaywallView(source: "onboarding")
                .paywallAppearance()
        }
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(app: AppViewModel())
}
