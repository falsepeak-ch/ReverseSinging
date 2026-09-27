//
//  MacWelcomeViewModel.swift
//  DubloonMac
//
//  The first-run window: what the app does, then the microphone
//

import SwiftUI
import Combine

/// Drives the Mac's welcome window.
///
/// The iPhone's onboarding is four swiped pages. A Mac app says hello the way the system's own
/// apps do: one window listing what is inside, then the one permission it needs. The asking,
/// the answer and finishing are `OnboardingViewModel`'s, so both platforms count and record
/// onboarding the same way.
@MainActor
final class MacWelcomeViewModel: ObservableObject {

    enum Step {
        case welcome
        case microphone
    }

    @Published private(set) var step: Step = .welcome

    let onboarding: OnboardingViewModel
    private var cancellables = Set<AnyCancellable>()

    init(app: AppViewModel) {
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

    var primaryTitle: String {
        step == .welcome ? Strings.Onboarding.buttonMicrophoneContinue : onboarding.buttonTitle.localizedCapitalized
    }

    func primaryAction() {
        switch step {
        case .welcome:
            withAnimation(.rsSmooth) { step = .microphone }
        case .microphone:
            onboarding.permissionButtonTapped()
        }
    }

    /// Leaves the microphone for later: every game asks again when it first records.
    func skip() {
        onboarding.finishOnboarding()
    }

    var isDenied: Bool { onboarding.isPermissionDenied }

    func scenePhaseDidChange(_ phase: ScenePhase) {
        onboarding.scenePhaseDidChange(phase)
    }
}
