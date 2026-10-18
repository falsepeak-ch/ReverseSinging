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
            #expect(!viewModel.offersPro)
        }
    }

    /// Without Dubloon Pro every game still opens: the free takes are spent inside them.
    @Test(arguments: GameMode.allCases)
    func everyGameOpensWithoutDubloonPro(mode: GameMode) {
        withAccess(.locked) {
            let viewModel = HomeViewModel()

            viewModel.open(mode)

            #expect(viewModel.offersPro)
            #expect(viewModel.path == [mode])
            #expect(viewModel.paywallSource == nil)
        }
    }

    /// Even with every free take used, the menu opens games rather than the paywall.
    @Test func gamesOpenOnceTheFreeTakesAreUsedUp() {
        withAccess(.locked) {
            let access = AccessController.shared
            let previous = access.freeTakesUsed
            access.overrideFreeTakesUsedForTesting(FreeTakes.limit)
            defer { access.overrideFreeTakesUsedForTesting(previous) }
            let viewModel = HomeViewModel()

            viewModel.open(.dub)

            #expect(viewModel.freeTakesLeft == 0)
            #expect(viewModel.path == [.dub])
            #expect(viewModel.paywallSource == nil)
        }
    }

    /// A pack opened from Files goes to the library whether or not Pro is owned.
    @Test func anImportWithoutProOpensTheLibrary() {
        withAccess(.locked) {
            let viewModel = HomeViewModel()
            let app = makeApp()
            let pack = URL(fileURLWithPath: "/tmp/pack.zip")
            app.pendingDubImportURL = pack
            app.showDubLibrary = true

            viewModel.dubLibraryRequestDidChange(true, app: app)

            #expect(viewModel.path == [.dub])
            #expect(viewModel.paywallSource == nil)
            #expect(!app.showDubLibrary)
            #expect(app.pendingDubImportURL == pack)
        }
    }

    /// A subscription that runs out overnight leaves the open game where it is.
    @Test func expiringInsideAGameKeepsItOpen() {
        withAccess(.unlocked(.entitlement)) {
            let viewModel = HomeViewModel()
            viewModel.open(.dub)

            AccessController.shared.overrideStateForTesting(.locked)

            #expect(viewModel.path == [.dub])
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
    /// their own or some wins behind them.
    private func makePrompt(days: Int = 0, importedPack: Bool = false, wins: Int = 0) -> ReviewPrompt {
        let name = "HomeViewModelTests.prompt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let prompt = ReviewPrompt(defaults: defaults)
        for day in 0..<days {
            prompt.registerAppOpen(now: Date(timeIntervalSince1970: 1_800_000_000 + Double(day) * 86_400))
        }
        if importedPack { prompt.registerImportedPack() }
        for _ in 0..<wins { prompt.registerWin() }
        return prompt
    }

    private func makeViewModel(banner: ReviewBanner? = nil, prompt: ReviewPrompt? = nil) -> HomeViewModel {
        HomeViewModel(
            reviewBanner: banner ?? makeBanner(),
            reviewPrompt: prompt ?? makePrompt(days: 2, importedPack: true)
        )
    }

    /// Whoever imported a pack and used the app on two days is asked, paid or not, and only
    /// a buyer is thanked for buying.
    @Test(arguments: [AccessState.unlocked(.entitlement), .locked])
    func anImporterOnTheirSecondDayIsAsked(state: AccessState) {
        withAccess(state) {
            let viewModel = makeViewModel()
            #expect(viewModel.showsReviewBanner)
            #expect(viewModel.reviewBannerThanksForPro == (state == .unlocked(.entitlement)))
        }
    }

    /// A free player who keeps scoring well is asked without importing anything.
    @Test func aWinnerOnTheirSecondDayIsAsked() {
        withAccess(.locked) {
            #expect(makeViewModel(prompt: makePrompt(days: 2, wins: 3)).showsReviewBanner)
        }
    }

    /// Paying is not enough on its own, and neither is days of use without an import or wins,
    /// nor an import or wins on a single day.
    @Test func withoutAnImportOrWinsAndTwoDaysNobodyIsAsked() {
        withAccess(.unlocked(.entitlement)) {
            #expect(!makeViewModel(prompt: makePrompt()).showsReviewBanner)
            #expect(!makeViewModel(prompt: makePrompt(days: 3)).showsReviewBanner)
            #expect(!makeViewModel(prompt: makePrompt(days: 3, wins: 2)).showsReviewBanner)
            #expect(!makeViewModel(prompt: makePrompt(days: 1, importedPack: true)).showsReviewBanner)
            #expect(!makeViewModel(prompt: makePrompt(days: 1, wins: 5)).showsReviewBanner)
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
