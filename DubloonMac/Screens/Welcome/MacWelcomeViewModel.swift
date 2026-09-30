//
//  MacWelcomeViewModel.swift
//  DubloonMac
//
//  The first-run window: what the app does
//

import SwiftUI
import Combine

/// Drives the Mac's welcome window.
///
/// The iPhone's onboarding is four swiped pages. A Mac app says hello the way the system's own
/// apps do: one window listing what is inside. Finishing is `OnboardingViewModel`'s, so both
/// platforms count and record onboarding the same way.
@MainActor
final class MacWelcomeViewModel: ObservableObject {

    let onboarding: OnboardingViewModel
    private let app: AppViewModel
    private var cancellables = Set<AnyCancellable>()

    init(app: AppViewModel) {
        self.app = app
        onboarding = OnboardingViewModel(app: app)
        onboarding.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// The three games, in the order the sidebar lists them.
    let features: [GameMode] = [.reverse, .dub, .imitate]

    func onAppear() {
        onboarding.onAppear()
    }

    // MARK: - Buttons

    /// Continue closes the window. Nothing is asked for here: every game asks for the
    /// microphone itself, the first time it records.
    var primaryTitle: String { Strings.Onboarding.buttonMicrophoneContinue }

    func primaryAction() {
        onboarding.finishOnboarding()
    }

    /// The window closed with its close button: onboarding is over, so it is not back at the
    /// next launch. Every game asks for the microphone itself when it first records.
    func windowDidClose() {
        if !app.hasCompletedOnboarding { onboarding.finishOnboarding() }
    }
}
