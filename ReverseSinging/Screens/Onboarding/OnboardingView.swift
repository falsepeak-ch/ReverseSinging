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
    @Environment(\.scenePhase) private var scenePhase

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

                TabView(selection: $viewModel.currentPage) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

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
                VStack(spacing: 16) {
                    if viewModel.isOnPermissionPage {
                        // Last page: the microphone ask, as a single dynamic button
                        BigButton(
                            title: viewModel.buttonTitle,
                            icon: viewModel.buttonIcon,
                            color: viewModel.buttonColor,
                            action: viewModel.permissionButtonTapped,
                            style: .primary
                        )

                        // A denial shouldn't trap anyone on the last page, the
                        // games ask again themselves when a recording is due.
                        if viewModel.isPermissionDenied {
                            Button(action: viewModel.finishOnboarding) {
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
                            action: viewModel.nextPage,
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
                .animation(.rsSpring, value: viewModel.currentPage)
            }
        }
        .onAppear { viewModel.onAppear() }
        .onChange(of: scenePhase) { _, phase in
            viewModel.scenePhaseDidChange(phase)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(app: AppViewModel())
}
