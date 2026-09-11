//
//  AppViewModelTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
@testable import ReverseSinging

/// Every test gets a `UserDefaults` suite of its own, so nothing here depends on, or leaves
/// behind, what the simulator has already seen.
@Suite("App View Model") @MainActor
struct AppViewModelTests {

    private func makeDefaults() -> UserDefaults {
        let name = "AppViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func freshInstall() {
        let viewModel = AppViewModel(defaults: makeDefaults())

        #expect(!viewModel.hasCompletedOnboarding)
        #expect(viewModel.uiMode == .simple)
        #expect(viewModel.hapticsEnabled)
    }

    @Test func completeOnboarding() {
        let viewModel = AppViewModel(defaults: makeDefaults())

        viewModel.completeOnboarding()

        #expect(viewModel.hasCompletedOnboarding)
    }

    /// Onboarding survives a relaunch.
    @Test func completedOnboardingIsRemembered() {
        let defaults = makeDefaults()

        AppViewModel(defaults: defaults).completeOnboarding()

        #expect(AppViewModel(defaults: defaults).hasCompletedOnboarding,
                "a fresh launch should not put the user back through onboarding")
    }

    @Test func preferencesAreRemembered() {
        let defaults = makeDefaults()
        let viewModel = AppViewModel(defaults: defaults)

        viewModel.setUIMode(.complex)
        viewModel.setHapticsEnabled(false)

        let relaunched = AppViewModel(defaults: defaults)
        #expect(relaunched.uiMode == .complex)
        #expect(!relaunched.hapticsEnabled)
    }

    /// `EarlyAdopter` and `BoothCamAnnouncement` read these keys from installs that predate
    /// this view model, and `HapticManager` reads the haptics one, so they must not change.
    @Test func writesTheKeysInstallsAlreadyHave() {
        let defaults = makeDefaults()
        let viewModel = AppViewModel(defaults: defaults)

        viewModel.completeOnboarding()
        viewModel.setUIMode(.complex)
        viewModel.setHapticsEnabled(false)

        #expect(defaults.bool(forKey: "hasCompletedOnboarding"))
        #expect(defaults.string(forKey: "uiMode") == "complex")
        #expect(defaults.object(forKey: "hapticsEnabled") as? Bool == false)
    }
}
