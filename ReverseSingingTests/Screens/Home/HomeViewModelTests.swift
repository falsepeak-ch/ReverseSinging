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
    func everyGameOpensWithDubloonPro(mode: GameMode) {
        withAccess(.unlocked(.entitlement)) {
            let viewModel = HomeViewModel()

            viewModel.open(mode)

            #expect(viewModel.path == [mode])
            #expect(viewModel.paywallSource == nil)
        }
    }

    /// Without Dubloon Pro dubbing answers a tap with the paywall, and is not pushed.
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

    /// Reverse singing is free: it opens without Dubloon Pro, and the menu says it is free.
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

    /// Home Video Dub is always free: the user brings the video, so it opens without Dubloon Pro.
    @Test func homeVideoDubStaysOpenWhenLocked() {
        withAccess(.locked) {
            let viewModel = HomeViewModel()

            viewModel.open(.homeVideo)

            #expect(!viewModel.isLocked(.homeVideo))
            #expect(viewModel.isFree(.homeVideo))
            #expect(viewModel.path == [.homeVideo])
            #expect(viewModel.paywallSource == nil)
        }
    }

    /// Sound Imitation is paid, so it locks with dubbing.
    @Test func soundImitationLocksWithDubbing() {
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
        withAccess(.unlocked(.entitlement)) {
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

    /// A subscription that runs out overnight with dubbing open closes it.
    @Test func expiringInsideAPaidGameReturnsToTheMenu() {
        withAccess(.unlocked(.entitlement)) {
            let viewModel = HomeViewModel()
            viewModel.open(.dub)

            AccessController.shared.overrideStateForTesting(.locked)

            #expect(viewModel.path.isEmpty)
        }
    }

    /// The same moment inside reverse singing changes nothing: it was never paid for.
    @Test func expiringInsideTheFreeGameKeepsItOpen() {
        withAccess(.unlocked(.entitlement)) {
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

    /// A prompt with its own counters: a newcomer, or someone with days of use and a pack of
    /// their own behind them.
    private func makePrompt(days: Int = 0, importedPack: Bool = false) -> ReviewPrompt {
        let name = "HomeViewModelTests.prompt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let prompt = ReviewPrompt(defaults: defaults)
        for day in 0..<days {
            prompt.registerAppOpen(now: Date(timeIntervalSince1970: 1_800_000_000 + Double(day) * 86_400))
        }
        if importedPack { prompt.registerImportedPack() }
        return prompt
    }

    private func makeViewModel(banner: ReviewBanner? = nil, prompt: ReviewPrompt? = nil) -> HomeViewModel {
        HomeViewModel(
            reviewBanner: banner ?? makeBanner(),
            reviewPrompt: prompt ?? makePrompt(days: 3, importedPack: true)
        )
    }

    /// Whoever imported a pack and used the app on three days is asked, paid or not, and only
    /// a buyer is thanked for buying.
    @Test(arguments: [AccessState.unlocked(.entitlement), .locked, .unlocked(.earlyAdopter)])
    func anImporterOnTheirThirdDayIsAsked(state: AccessState) {
        withAccess(state) {
            let viewModel = makeViewModel()
            #expect(viewModel.showsReviewBanner)
            #expect(viewModel.reviewBannerThanksForPro == (state == .unlocked(.entitlement)))
        }
    }

    /// Paying is not enough on its own, and neither is one of the two conditions without the
    /// other.
    @Test func withoutAnImportAndThreeDaysNobodyIsAsked() {
        withAccess(.unlocked(.entitlement)) {
            #expect(!makeViewModel(prompt: makePrompt()).showsReviewBanner)
            #expect(!makeViewModel(prompt: makePrompt(days: 3)).showsReviewBanner)
            #expect(!makeViewModel(prompt: makePrompt(days: 2, importedPack: true)).showsReviewBanner)
        }
    }

    /// A star leads to the App Store offer or to the feedback dialog, and backing out of
    /// either leaves the banner up with its stars cleared.
    @Test func aRatingOpensTheRightDialog() {
        withAccess(.locked) {
            let viewModel = makeViewModel()

            viewModel.rateFromReviewBanner(stars: 5)
            #expect(viewModel.isReviewStoreAskPresented && !viewModel.isReviewFeedbackPresented)
            viewModel.isReviewStoreAskPresented = false
            viewModel.reviewDialogDidCancel()

            viewModel.rateFromReviewBanner(stars: 2)
            #expect(viewModel.isReviewFeedbackPresented && viewModel.reviewStars == 2)
            viewModel.reviewDialogDidCancel()
            #expect(!viewModel.isReviewFeedbackPresented && viewModel.reviewStars == 0)
            #expect(viewModel.showsReviewBanner)
        }
    }

    @Test func sendingFeedbackPutsTheBannerAway() {
        withAccess(.locked) {
            let viewModel = makeViewModel()
            viewModel.rateFromReviewBanner(stars: 1)
            _ = viewModel.sendReviewFeedback("Exports take too long")

            #expect(!viewModel.isReviewFeedbackPresented)
            #expect(!viewModel.showsReviewBanner)
        }
    }

    /// With Share Usage Data off the note goes by email, and the banner is only done once Mail
    /// has taken it: a phone with no mail account keeps the dialog, the note and the banner.
    @Test func feedbackByMailOnlyCountsOnceMailOpens() {
        withAccess(.locked) {
            let viewModel = makeViewModel()
            viewModel.rateFromReviewBanner(stars: 2)

            viewModel.reviewFeedbackMailDidOpen(false)
            #expect(viewModel.isReviewFeedbackPresented)
            #expect(viewModel.showsReviewBanner)

            viewModel.reviewFeedbackMailDidOpen(true)
            #expect(!viewModel.isReviewFeedbackPresented)
            #expect(!viewModel.showsReviewBanner)
        }
    }

    @Test func answeringTheBannerPutsItAway() {
        withAccess(.unlocked(.entitlement)) {
            let banner = makeBanner()
            let rated = makeViewModel(banner: banner)
            #expect(rated.reviewBannerWentToStore() == ReviewBanner.writeReviewURL)
            #expect(!rated.showsReviewBanner)
            #expect(!makeViewModel(banner: banner).showsReviewBanner)

            let dismissed = makeViewModel()
            dismissed.dismissReviewBanner()
            #expect(!dismissed.showsReviewBanner)
        }
    }
}
