//
//  ContentView.swift
//  ReverseSinging
//
//  Root view handling onboarding and main app
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel

    /// - Parameter app: the app-wide state, when something outside this view shares it. The
    ///   Mac's Settings window does; the iPhone's root owns its own.
    init(app: AppViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: app ?? AppViewModel())
    }
    var body: some View {
        Group {
            if viewModel.hasCompletedOnboarding {
                // The menu is the root; each game is pushed from it. The UI mode
                // preference picks how reverse singing looks, one level deeper.
                HomeView()
                    .environmentObject(viewModel)
            } else {
                OnboardingView(app: viewModel)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .appLifecycle(app: viewModel)
    }

    /// The editor interface is dark-only: a light UI washes out the stills and
    /// waveforms it exists to display, the same reason real editors ship dark.
    private var preferredColorScheme: ColorScheme? { .dark }
}

// MARK: - Lifecycle

extension View {
    /// What the root does around whichever screen is showing: the paywall, a pack handed in
    /// from outside, and counting opens. Shared by the iPhone's root and the Mac window.
    func appLifecycle(app: AppViewModel) -> some View {
        modifier(AppLifecycleModifier(app: app))
    }
}

private struct AppLifecycleModifier: ViewModifier {
    @ObservedObject var app: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    /// Nil until the first activation, so a cold launch counts as an open too.
    @State private var previousScenePhase: ScenePhase?

    func body(content: Content) -> some View {
        content
            // Above onboarding as well as the games: the free window runs from first
            // launch, so a user who installs, plays for eight days and only then
            // finishes onboarding still meets the paywall.
            .hardPaywall()
            .onOpenURL { url in
                // A dub pack arrived from Files, AirDrop or "Open with"
                app.pendingDubImportURL = url
                app.showDubLibrary = true
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                handleScenePhase(phase)
            }
            #if DEBUG
            // `-importPacksFrom <folder>`: bring in a folder of packs and print a verdict for each.
            .task { await DebugImportRun.runIfRequested() }
            #endif
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
        guard app.hasCompletedOnboarding else { return }
        Task {
            try? await Task.sleep(for: .seconds(2))
            ReviewPrompt.shared.requestIfAppropriate(trigger: "app_open")
        }
    }
}

#Preview("Onboarding") {
    ContentView()
}
