//
//  OnboardingViewModelTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
import SwiftUI
@testable import ReverseSinging

/// Every test gets a `UserDefaults` suite of its own, so nothing here depends on, or leaves
/// behind, what the simulator has already seen. The microphone prompt itself is the system's
/// and is not driven from here.
@Suite("Onboarding View Model") @MainActor
struct OnboardingViewModelTests {

    private func makeApp() -> AppViewModel {
        let name = "OnboardingViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AppViewModel(defaults: defaults)
    }

    @Test func startsOnTheFirstPageWithTheMicrophoneNotYetAsked() {
        let viewModel = OnboardingViewModel(app: makeApp())

        #expect(viewModel.currentPage == 0)
        #expect(!viewModel.isOnPermissionPage)
        #expect(viewModel.permissionStep == .undetermined)
        #expect(viewModel.buttonTitle == Strings.Onboarding.buttonMicrophoneContinue)
        #expect(viewModel.buttonIcon == "mic.fill")
    }

    /// The microphone ask is the last page, and continuing never runs past it.
    @Test func continuingStopsOnTheMicrophoneAsk() {
        let viewModel = OnboardingViewModel(app: makeApp())

        for _ in 0..<(viewModel.pages.count + 2) {
            viewModel.nextPage()
        }

        #expect(viewModel.currentPage == viewModel.pages.count - 1)
        #expect(viewModel.isOnPermissionPage)
    }

    /// The reverse game opens in its simple skin, whatever was picked before.
    @Test func finishingOpensTheAppInTheSimpleSkin() {
        let app = makeApp()
        app.setUIMode(.complex)
        let viewModel = OnboardingViewModel(app: app)

        viewModel.finishOnboarding()

        #expect(app.hasCompletedOnboarding)
        #expect(app.uiMode == .simple)
    }

    /// Coming back to the app re-checks the microphone only after a denial. Before the ask
    /// there is nothing to move the button on from.
    @Test func returningBeforeTheAskChangesNothing() {
        let viewModel = OnboardingViewModel(app: makeApp())

        viewModel.scenePhaseDidChange(.active)

        #expect(viewModel.permissionStep == .undetermined)
    }
}
