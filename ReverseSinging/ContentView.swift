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
                // The menu is the root; each game is pushed from it. The UI mode
                // preference picks how reverse singing looks, one level deeper.
                HomeView()
                    .environmentObject(viewModel)
            } else {
                OnboardingView(viewModel: viewModel)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onOpenURL { url in
            // A dub pack arrived from Files, AirDrop or "Open with"
            viewModel.pendingDubImportURL = url
            viewModel.showDubLibrary = true
        }
    }

    /// The editor interface is dark-only — a light UI washes out the stills and
    /// waveforms it exists to display, the same reason real editors ship dark.
    private var preferredColorScheme: ColorScheme? { .dark }
}

#Preview("Onboarding") {
    ContentView()
}
