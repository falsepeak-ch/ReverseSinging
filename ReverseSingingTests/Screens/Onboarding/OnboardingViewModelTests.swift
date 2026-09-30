//
//  OnboardingViewModelTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
import SwiftUI
@testable import ReverseSinging

/// Every test gets a `UserDefaults` suite of its own, so nothing here depends on, or leaves
/// behind, what the simulator has already seen.
@Suite("Onboarding View Model") @MainActor
struct OnboardingViewModelTests {

    private func makeApp() -> AppViewModel {
        let name = "OnboardingViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AppViewModel(defaults: defaults)
    }

    @Test func startsOnTheFirstPage() {
        let viewModel = OnboardingViewModel(app: makeApp())

        #expect(viewModel.currentPage == 0)
        #expect(!viewModel.isOnLastPage)
    }

    /// Going on never runs past the last page.
    @Test func nextPageStopsOnTheLastPage() {
        let viewModel = OnboardingViewModel(app: makeApp())

        for _ in 0..<(viewModel.pages.count + 2) {
            viewModel.nextPage()
        }

        #expect(viewModel.currentPage == viewModel.pages.count - 1)
        #expect(viewModel.isOnLastPage)
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

    /// Dubloon Pro is explained last, once the games it pays for have been shown. Nothing on
    /// any page asks for the microphone: the games do that when record is first pressed.
    @Test func proIsExplainedLast() {
        let pages = OnboardingViewModel(app: makeApp()).pages

        #expect(pages.last?.title == Strings.Onboarding.proTitle)
    }

    /// The button moves on until the last page, where it opens the app.
    @Test func continuingFromTheLastPageFinishesOnboarding() {
        let app = makeApp()
        let viewModel = OnboardingViewModel(app: app)

        for _ in 0..<(viewModel.pages.count - 1) { viewModel.continueTapped() }
        #expect(viewModel.isOnLastPage)
        #expect(!app.hasCompletedOnboarding)

        viewModel.continueTapped()
        #expect(app.hasCompletedOnboarding)
    }
}
