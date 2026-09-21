//
//  PaywallEligibilityTests.swift
//  ReverseSingingTests
//
//  Who may be shown a paywall: downloads on or after the console's date, nobody else
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Paywall Eligibility")
struct PaywallEligibilityTests {

    /// The console's `2026-09-18`, parsed the way the app parses it.
    private let cutoff = RemoteConfigService.parseReleaseDate("2026-09-18")!

    // MARK: - The boundary

    /// The last instant of the day before is still before.
    @Test func oneSecondBeforeTheDateIsExempt() {
        let downloadedAt = cutoff.addingTimeInterval(-1)
        #expect(PaywallEligibility(downloadedAt: downloadedAt, cutoff: cutoff) == .exempt)
    }

    /// "Equal or later": the first instant of the day itself is on the paying side.
    @Test func theDateItselfIsEligible() {
        #expect(PaywallEligibility(downloadedAt: cutoff, cutoff: cutoff) == .eligible)
    }

    @Test func anyTimeDuringTheDateIsEligible() {
        let downloadedAt = cutoff.addingTimeInterval(13 * 3600)
        #expect(PaywallEligibility(downloadedAt: downloadedAt, cutoff: cutoff) == .eligible)
    }

    @Test func laterIsEligible() {
        let downloadedAt = cutoff.addingTimeInterval(90 * 86_400)
        #expect(PaywallEligibility(downloadedAt: downloadedAt, cutoff: cutoff) == .eligible)
    }

    @Test func longBeforeIsExempt() {
        let downloadedAt = cutoff.addingTimeInterval(-400 * 86_400)
        #expect(PaywallEligibility(downloadedAt: downloadedAt, cutoff: cutoff) == .exempt)
    }

    /// The boundary is midnight UTC wherever the phone is: 23:30 on the 17th in New York is
    /// already 03:30 UTC on the 18th, and the receipt's date is an instant, not a local day.
    @Test func theBoundaryIsUTCNotTheDevicesDay() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let lateOnThe17thLocally = try #require(newYork.date(from: DateComponents(
            year: 2026, month: 9, day: 17, hour: 23, minute: 30
        )))

        #expect(PaywallEligibility(downloadedAt: lateOnThe17thLocally, cutoff: cutoff) == .eligible)
    }

    // MARK: - Not knowing

    /// No download date, no paywall: the store not having said is not evidence of anything.
    @Test func anUnknownDownloadDateIsNeverEligible() {
        #expect(PaywallEligibility(downloadedAt: nil, cutoff: cutoff) == .undetermined)
    }

    /// No console date, no paywall — and no exemption either, since that one is permanent.
    @Test func anUnknownCutoffIsNeverEligibleAndNeverExempt() {
        let longAgo = Date(timeIntervalSince1970: 0)
        #expect(PaywallEligibility(downloadedAt: longAgo, cutoff: nil) == .undetermined)
        #expect(PaywallEligibility(downloadedAt: .distantFuture, cutoff: nil) == .undetermined)
    }

    @Test func nothingKnownIsUndetermined() {
        #expect(PaywallEligibility(downloadedAt: nil, cutoff: nil) == .undetermined)
    }

    // MARK: - The first-launch fallback

    /// The store had no date, and the app was first opened after the cutoff: gated.
    @Test func aFirstLaunchOnOrAfterTheDateIsEligibleWhenTheStoreHasNoDate() {
        #expect(PaywallEligibility(downloadedAt: nil, firstLaunchedAt: cutoff, cutoff: cutoff) == .eligible)
        #expect(PaywallEligibility(
            downloadedAt: nil, firstLaunchedAt: cutoff.addingTimeInterval(86_400), cutoff: cutoff
        ) == .eligible)
    }

    /// One direction only. A first launch before the cutoff proves nothing: the device clock
    /// can be set back, and `exempt` is permanent, so it is only ever reached on Apple's date.
    @Test func aFirstLaunchBeforeTheDateNeverExempts() {
        let before = cutoff.addingTimeInterval(-1)
        #expect(PaywallEligibility(downloadedAt: nil, firstLaunchedAt: before, cutoff: cutoff) == .undetermined)

        let longBefore = Date(timeIntervalSince1970: 0)
        #expect(PaywallEligibility(downloadedAt: nil, firstLaunchedAt: longBefore, cutoff: cutoff) == .undetermined)
    }

    /// Apple's date wins whenever there is one. The case that matters: an early user who
    /// reinstalled after the cutoff is dated by the receipt, not by the reinstall.
    @Test func applesDateOverridesTheFirstLaunchDate() {
        let reinstalledAfter = cutoff.addingTimeInterval(30 * 86_400)
        let downloadedBefore = cutoff.addingTimeInterval(-30 * 86_400)
        #expect(PaywallEligibility(
            downloadedAt: downloadedBefore, firstLaunchedAt: reinstalledAfter, cutoff: cutoff
        ) == .exempt)

        #expect(PaywallEligibility(
            downloadedAt: reinstalledAfter, firstLaunchedAt: downloadedBefore, cutoff: cutoff
        ) == .eligible)
    }

    /// The fallback does not get round a missing cutoff.
    @Test func theFallbackStillNeedsTheConsolesDate() {
        #expect(PaywallEligibility(downloadedAt: nil, firstLaunchedAt: .distantFuture, cutoff: nil) == .undetermined)
    }

    // MARK: - Recording the first launch

    @Test func theFirstLaunchIsRecordedOnceAndNeverMoved() {
        let firstLaunch = FirstLaunchDate(defaults: makeDefaults())
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(firstLaunch.date == nil)

        #expect(firstLaunch.record(now: first) == first)
        #expect(firstLaunch.record(now: first.addingTimeInterval(86_400 * 30)) == first)
        #expect(firstLaunch.date == first)
    }

    /// An install that was already counting down a trial is dated from that, not from the
    /// launch that shipped this.
    @Test func anInstallAlreadyOnATrialIsDatedFromItsAnchor() {
        let defaults = makeDefaults()
        let anchor = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(anchor, forKey: "trial.startedAt")

        let recorded = FirstLaunchDate(defaults: defaults).record(now: anchor.addingTimeInterval(86_400 * 10))

        #expect(recorded == anchor)
    }

    /// A trial anchor left by a clock that has since moved back must not date the install in
    /// the future.
    @Test func aFutureTrialAnchorIsNotBelieved() {
        let defaults = makeDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(now.addingTimeInterval(86_400 * 365), forKey: "trial.startedAt")

        #expect(FirstLaunchDate(defaults: defaults).record(now: now) == now)
    }

    // MARK: - The permanent grant

    private func makeDefaults() -> UserDefaults {
        let name = "PaywallEligibilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// The exemption cannot be taken back, so it is only handed out on two known dates.
    @Test @MainActor func theExemptionIsNotGrantedWithoutBothDates() {
        let earlyAdopter = EarlyAdopter(defaults: makeDefaults())
        let longAgo = Date(timeIntervalSince1970: 0)

        earlyAdopter.considerOriginalPurchaseDate(longAgo, before: nil)
        earlyAdopter.considerOriginalPurchaseDate(nil, before: cutoff)

        #expect(!earlyAdopter.isEarlyAdopter)
    }

    @Test @MainActor func theExemptionFollowsTheSameBoundary() {
        let onTheDate = EarlyAdopter(defaults: makeDefaults())
        onTheDate.considerOriginalPurchaseDate(cutoff, before: cutoff)
        #expect(!onTheDate.isEarlyAdopter)

        let justBefore = EarlyAdopter(defaults: makeDefaults())
        justBefore.considerOriginalPurchaseDate(cutoff.addingTimeInterval(-1), before: cutoff)
        #expect(justBefore.isEarlyAdopter)
    }
}
