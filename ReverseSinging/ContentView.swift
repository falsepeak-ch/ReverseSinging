//
//  ContentView.swift
//  ReverseSinging
//
//  Root view handling onboarding and main app
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AudioViewModel()
    @Environment(\.scenePhase) private var scenePhase

    /// Nil until the first activation, so a cold launch counts as an open too.
    @State private var previousScenePhase: ScenePhase?

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
        // Above onboarding as well as the games: the free window runs from first
        // launch, so a user who installs, plays for eight days and only then
        // finishes onboarding still meets the paywall.
        .hardPaywall()
        .onOpenURL { url in
            // A dub pack arrived from Files, AirDrop or "Open with"
            viewModel.pendingDubImportURL = url
            viewModel.showDubLibrary = true
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            handleScenePhase(phase)
        }
    }

    /// Counts an open on a launch or a return from the background — not on the flickers
    /// between `.active` and `.inactive` that a notification banner causes.
    @MainActor
    private func handleScenePhase(_ phase: ScenePhase) {
        defer { previousScenePhase = phase }
        guard phase == .active else { return }
        #if DEBUG
        // A screenshot run drives the app through a cold launch per locale. Those are
        // not opens, and nobody is there to rate anything.
        if ScreenshotMode.isActive { return }
        #endif
        guard previousScenePhase == nil || previousScenePhase == .background else { return }

        // A trial that ran out overnight, or a purchase made on another device,
        // is noticed here rather than on the next cold launch.
        AccessController.shared.refreshOnForeground()

        ReviewPrompt.shared.registerAppOpen()

        // Onboarding is the wrong moment to ask for anything, and the ask reads better
        // once the screen has settled rather than on top of the launch animation.
        guard viewModel.appState.hasCompletedOnboarding else { return }
        Task {
            try? await Task.sleep(for: .seconds(2))
            ReviewPrompt.shared.requestIfAppropriate(trigger: "app_open")
        }
    }

    /// The editor interface is dark-only: a light UI washes out the stills and
    /// waveforms it exists to display, the same reason real editors ship dark.
    private var preferredColorScheme: ColorScheme? { .dark }
}

#Preview("Onboarding") {
    ContentView()
}
