//
//  OnboardingView.swift
//  ReverseSinging
//
//  Voxxa-inspired onboarding with gradient icons
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

            VStack(spacing: 32) {
                // Back button placeholder (like Voxxa has in header)
                HStack {
                    Spacer()
                }
                .frame(height: 44)
                .padding(.top, 8)

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
                .padding(.bottom, 20)

                // Buttons
                BigButton(
                    title: Strings.Onboarding.buttonContinueLowercase,
                    icon: "arrow.right",
                    color: .rsTurquoise,
                    action: viewModel.continueTapped,
                    style: .primary
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .animation(.rsSpring, value: viewModel.currentPage)
            }
        }
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(app: AppViewModel())
}
