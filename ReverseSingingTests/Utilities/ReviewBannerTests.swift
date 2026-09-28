//
//  ReviewBannerTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Review Banner") @MainActor
struct ReviewBannerTests {

    private func makeBanner() -> ReviewBanner {
        let name = "ReviewBannerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ReviewBanner(defaults: defaults)
    }

    @Test func isDueUntilAnswered() {
        #expect(makeBanner().isDue())
    }

    /// Tapping through ends it, whether or not a review was written: the app cannot tell.
    @Test func goingToTheStoreEndsIt() {
        let banner = makeBanner()
        banner.recordWentToStore()
        #expect(!banner.isDue(now: .distantFuture))
    }

    /// "Not now" once puts it away for a week, then it comes back.
    @Test func notNowSnoozesForAWeek() {
        let banner = makeBanner()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        banner.recordDismissed(now: now)

        #expect(!banner.isDue(now: now.addingTimeInterval(ReviewBanner.snoozeInterval - 1)))
        #expect(banner.isDue(now: now.addingTimeInterval(ReviewBanner.snoozeInterval)))
    }

    /// "Not now" twice is a no.
    @Test func notNowTwiceEndsIt() {
        let banner = makeBanner()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        banner.recordDismissed(now: now)
        banner.recordDismissed(now: now.addingTimeInterval(ReviewBanner.snoozeInterval))

        #expect(!banner.isDue(now: .distantFuture))
    }

    @Test func linksToTheReviewForm() {
        let url = ReviewBanner.writeReviewURL
        #expect(url.host == "apps.apple.com")
        #expect(url.query == "action=write-review")
    }
}
