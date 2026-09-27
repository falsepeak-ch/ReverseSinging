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

    /// Once the trial is over dubbing answers a tap with the paywall, and is not pushed.
    @Test func aLockedGameOpensThePaywallInstead() {
        withAccess(.locked) {
            let viewModel = HomeViewModel()

            viewModel.open(.dub)

            #expect(viewModel.areGamesLocked)
            #expect(viewModel.isLocked(.dub))
            #expect(viewModel.path.isEmpty)
            #expect(viewModel.paywallSource == .lockedGame)
        }
    }

    /// Reverse singing is free: it opens with the trial over, and the menu says it is free.
    @Test func theReverseGameStaysOpenWhenLocked() {
        withAccess(.locked) {
            let viewModel = HomeViewModel()

            viewModel.open(.reverse)

            #expect(!viewModel.isLocked(.reverse))
            #expect(viewModel.isFree(.reverse))
            #expect(!viewModel.isFree(.dub))
            #expect(viewModel.path == [.reverse])
            #expect(viewModel.paywallSource == nil)
        }
    }

    /// Sound Imitation is paid unless the console frees it, so it locks with dubbing.
    @Test func soundImitationLocksByDefault() {
        withAccess(.locked) {
            let viewModel = HomeViewModel()

            viewModel.open(.imitate)

            #expect(viewModel.isLocked(.imitate))
            #expect(!viewModel.isFree(.imitate))
            #expect(viewModel.path.isEmpty)
            #expect(viewModel.paywallSource == .lockedGame)
        }
    }

    /// "Free" only means something beside a padlock. With nothing locked, no game says it.
    @Test(arguments: GameMode.allCases)
    func nothingIsMarkedFreeWhileNothingIsLocked(mode: GameMode) {
        withAccess(.trial(daysRemaining: 3, endsAt: .distantFuture)) {
            #expect(!HomeViewModel().isFree(mode))
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

    /// A trial that runs out overnight with dubbing open closes it.
    @Test func expiringInsideAPaidGameReturnsToTheMenu() {
        withAccess(.trial(daysRemaining: 1, endsAt: .distantFuture)) {
            let viewModel = HomeViewModel()
            viewModel.open(.dub)

            AccessController.shared.overrideStateForTesting(.locked)

            #expect(viewModel.path.isEmpty)
        }
    }

    /// The same moment inside reverse singing changes nothing: it was never paid for.
    @Test func expiringInsideTheFreeGameKeepsItOpen() {
        withAccess(.trial(daysRemaining: 1, endsAt: .distantFuture)) {
            let viewModel = HomeViewModel()
            viewModel.open(.reverse)

            AccessController.shared.overrideStateForTesting(.locked)

            #expect(viewModel.path == [.reverse])
        }
    }

    // MARK: - Review banner

    private func makeBanner() -> ReviewBanner {
        let name = "HomeViewModelTests.banner.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ReviewBanner(defaults: defaults)
    }

    @Test func aBuyerIsAskedForAReview() {
        withAccess(.unlocked(.entitlement)) {
            #expect(HomeViewModel(reviewBanner: makeBanner()).showsReviewBanner)
        }
    }

    /// Nobody who has not paid is asked: not mid-trial, not locked, not an early adopter.
    @Test(arguments: [
        AccessState.trial(daysRemaining: 3, endsAt: .distantFuture),
        .locked,
        .unlocked(.earlyAdopter),
        .unlocked(.gatingDisabled),
        .unknown
    ])
    func onlyBuyersAreAskedForAReview(state: AccessState) {
        withAccess(state) {
            #expect(!HomeViewModel(reviewBanner: makeBanner()).showsReviewBanner)
        }
    }

    @Test func answeringTheBannerPutsItAway() {
        withAccess(.unlocked(.entitlement)) {
            let banner = makeBanner()
            let rated = HomeViewModel(reviewBanner: banner)
            #expect(rated.reviewBannerWentToStore() == ReviewBanner.writeReviewURL)
            #expect(!rated.showsReviewBanner)
            #expect(!HomeViewModel(reviewBanner: banner).showsReviewBanner)

            let dismissed = HomeViewModel(reviewBanner: makeBanner())
            dismissed.dismissReviewBanner()
            #expect(!dismissed.showsReviewBanner)
        }
    }
}
