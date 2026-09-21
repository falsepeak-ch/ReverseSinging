//
//  HomeViewModelTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
@testable import ReverseSinging

/// The access state is the app-wide singleton's, so these run one at a time and each puts back
/// what it found.
@Suite("Home View Model", .serialized) @MainActor
struct HomeViewModelTests {

    private func withAccess(_ state: AccessState, _ body: () -> Void) {
        let access = AccessController.shared
        let previous = access.state
        access.overrideStateForTesting(state)
        defer { access.overrideStateForTesting(previous) }
        body()
    }

    private func makeApp() -> AppViewModel {
        let name = "HomeViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AppViewModel(defaults: defaults)
    }

    @Test(arguments: GameMode.allCases)
    func aGameOpensDuringTheTrial(mode: GameMode) {
        withAccess(.trial(daysRemaining: 3, endsAt: .distantFuture)) {
            let viewModel = HomeViewModel()

            viewModel.open(mode)

            #expect(viewModel.path == [mode])
            #expect(viewModel.paywallSource == nil)
        }
    }

    /// Once the trial is over a game answers a tap with the paywall, and is not pushed.
    @Test(arguments: GameMode.allCases)
    func aLockedGameOpensThePaywallInstead(mode: GameMode) {
        withAccess(.locked) {
            let viewModel = HomeViewModel()

            viewModel.open(mode)

            #expect(viewModel.areGamesLocked)
            #expect(viewModel.path.isEmpty)
            #expect(viewModel.paywallSource == .lockedGame)
        }
    }

    /// A pack opened from Files must not be a way round the lock.
    @Test func anImportWhileLockedOpensThePaywallAndKeepsThePack() {
        withAccess(.locked) {
            let viewModel = HomeViewModel()
            let app = makeApp()
            let pack = URL(fileURLWithPath: "/tmp/pack.zip")
            app.pendingDubImportURL = pack
            app.showDubLibrary = true

            viewModel.dubLibraryRequestDidChange(true, app: app)

            #expect(viewModel.path.isEmpty)
            #expect(viewModel.paywallSource == .lockedImport)
            #expect(!app.showDubLibrary)
            #expect(app.pendingDubImportURL == pack)
        }
    }

    /// Buying from the paywall a pack led to carries on to the library, where the pack is
    /// taken in.
    @Test func buyingAfterALockedImportOpensTheLibrary() {
        withAccess(.locked) {
            let viewModel = HomeViewModel()
            viewModel.dubLibraryRequestDidChange(true, app: makeApp())

            AccessController.shared.overrideStateForTesting(.unlocked(.entitlement))

            #expect(viewModel.path == [.dub])
        }
    }

    /// Closing that paywall without buying drops the intent: a purchase made later, from
    /// settings, should not push a screen nobody asked for.
    @Test func closingThePaywallForgetsTheLockedImport() {
        withAccess(.locked) {
            let viewModel = HomeViewModel()
            viewModel.dubLibraryRequestDidChange(true, app: makeApp())
            viewModel.paywallSource = nil

            AccessController.shared.overrideStateForTesting(.unlocked(.entitlement))

            #expect(viewModel.path.isEmpty)
        }
    }

    /// A trial that runs out overnight with a game open closes the game.
    @Test func expiringInsideAGameReturnsToTheMenu() {
        withAccess(.trial(daysRemaining: 1, endsAt: .distantFuture)) {
            let viewModel = HomeViewModel()
            viewModel.open(.reverse)

            AccessController.shared.overrideStateForTesting(.locked)

            #expect(viewModel.path.isEmpty)
        }
    }
}
