//
//  ContentView.swift
//  ReverseSinging
//
//  Root view handling onboarding and main app
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AudioViewModel()

    var body: some View {
        Group {
            if viewModel.appState.hasCompletedOnboarding {
                // Route to appropriate main view based on UI mode preference
                if viewModel.appState.uiMode == .simple {
                    MainViewSimple()
                        .environmentObject(viewModel)
                } else {
                    MainViewPremium()
                        .environmentObject(viewModel)
                }
            } else {
                OnboardingView(viewModel: viewModel)
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
}

#Preview("Onboarding") {
    ContentView()
}
