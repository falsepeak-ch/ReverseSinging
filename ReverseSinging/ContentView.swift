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
                MainViewPremium()
                    .environmentObject(viewModel)
            } else {
                OnboardingView(viewModel: viewModel)
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
