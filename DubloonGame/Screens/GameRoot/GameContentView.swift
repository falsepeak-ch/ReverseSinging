//
//  GameContentView.swift
//  DubloonGame
//
//  The root: the stage, and the app-wide lifecycle around it.
//

import SwiftUI

/// The game's root. There is no onboarding: the host on the stage is the welcome, and the
/// microphone is explained at the first take, as in the iPhone app.
struct GameContentView: View {
    @StateObject private var app = AppViewModel()
    @ObservedObject private var appearance = AppearancePreference.shared

    var body: some View {
        GameHomeView()
            .environmentObject(app)
            .preferredColorScheme(appearance.mode.colorScheme)
            .onAppear {
                appearance.applyToWindows()
                // Shared code reads this as "has used the app"; the stage counts.
                if !app.hasCompletedOnboarding { app.completeOnboarding() }
            }
            .appLifecycle(app: app)
    }
}
