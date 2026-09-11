//
//  SettingsViewModelTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
@testable import ReverseSinging

/// The preferences here are `AppViewModel`'s, so every test gives it a `UserDefaults` suite of
/// its own. Sounds, the camera and the purchase are app-wide singletons and are left alone.
@Suite("Settings View Model") @MainActor
struct SettingsViewModelTests {

    private func makeApp() -> AppViewModel {
        let name = "SettingsViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AppViewModel(defaults: defaults)
    }

    /// The Simple/Complex skin belongs to reverse singing, so the menu's settings don't offer it.
    @Test func theInterfaceChoiceOnlyShowsFromTheReverseGame() {
        #expect(!SettingsViewModel(app: makeApp(), scope: .app).showsInterfaceSection)
        #expect(SettingsViewModel(app: makeApp(), scope: .reverseSinging).showsInterfaceSection)
    }

    /// The switches write to the app's own preferences, not to a copy that dies with the sheet.
    @Test func preferencesAreTheApps() {
        let app = makeApp()
        let viewModel = SettingsViewModel(app: app, scope: .reverseSinging)

        viewModel.setUIMode(.complex)
        viewModel.setHapticsEnabled(false)

        #expect(app.uiMode == .complex)
        #expect(!app.hapticsEnabled)
        #expect(viewModel.uiMode == .complex)
        #expect(!viewModel.hapticsEnabled)
    }

    @Test func versionComesFromTheBundle() throws {
        let version = try #require(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        let build = try #require(Bundle.main.infoDictionary?["CFBundleVersion"] as? String)

        let text = try #require(SettingsViewModel(app: makeApp(), scope: .app).versionText)

        #expect(text.contains(version))
        #expect(text.contains(build))
    }
}
