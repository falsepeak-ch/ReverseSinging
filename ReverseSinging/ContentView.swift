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
                MainView()
                    .environmentObject(viewModel)
            } else {
                OnboardingView(viewModel: viewModel)
            }
        }
        .onAppear {
            // Request microphone permission on first launch
            if !viewModel.appState.hasCompletedOnboarding {
                viewModel.requestPermission()
            }
        }
    }
}

#Preview("Onboarding") {
    ContentView()
}

#Preview("Main App") {
    let viewModel = AudioViewModel()
    viewModel.appState.hasCompletedOnboarding = true
    return MainView()
        .environmentObject(viewModel)
}
