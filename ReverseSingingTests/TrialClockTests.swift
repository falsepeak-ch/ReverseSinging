//
//  TrialClockTests.swift
//  ReverseSingingTests
//
//  The countdown that decides when the hard paywall appears
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Trial Clock")
struct TrialClockTests {

    /// A private defaults suite per test, so one test's anchor cannot leak into
    /// the next and none of them touch the real install's trial.
    private static func makeClock(
        _ name: String = UUID().uuidString
    ) -> (clock: TrialClock, defaults: UserDefaults) {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (TrialClock(defaults: defaults), defaults)
    }

    private static let day: TimeInterval = 86_400

    // MARK: - Anchoring

    /// The window opens on the first read, not on install and not on purchase.
    ///
    /// This is what grandfathers the users already on 1.3.2: they have no stored
    /// anchor, so the first launch of the build carrying the paywall gives them
    /// the whole window rather than finding it long spent.
    @Test func theWindowOpensOnFirstReadAndNeverMovesAfterwards() {
        let (clock, _) = Self.makeClock()
        let firstLaunch = Date(timeIntervalSince1970: 1_700_000_000)

        let anchor = clock.startDate(now: firstLaunch)
        #expect(anchor == firstLaunch)

        // Three days later the anchor is still the first launch, not the read.
        let later = firstLaunch.addingTimeInterval(3 * Self.day)
        #expect(clock.startDate(now: later) == firstLaunch)
    }

    @Test func hasStartedOnlyReportsTrueOnceTheWindowHasBeenOpened() {
        let (clock, _) = Self.makeClock()
        #expect(clock.hasStarted == false)

        clock.startDate()
        #expect(clock.hasStarted == true)
    }

    /// A device clock moved backwards must not produce a negative window.
    ///
    /// The anchor is trusted, but only in the direction that cannot lock someone
    /// out early: an anchor in the future is re-seeded to now, so the user gets a
    /// full window rather than a nonsensical one.
    @Test func anAnchorInTheFutureIsReSeededRatherThanBelieved() {
        let (clock, defaults) = Self.makeClock()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(now.addingTimeInterval(30 * Self.day), forKey: "trial.startedAt")

        #expect(clock.startDate(now: now) == now)
        #expect(clock.state(lengthInDays: 7, now: now) == .active(
            daysRemaining: 7, endsAt: now.addingTimeInterval(7 * Self.day)
        ))
    }

    // MARK: - Counting

    /// Day zero of a seven-day window reads "7", not "6" and not "8".
    @Test func aFreshWindowCountsItsFullLength() {
        let (clock, _) = Self.makeClock()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        guard case .active(let days, let endsAt) = clock.state(lengthInDays: 7, now: now) else {
            Issue.record("a window opened this instant should be active")
            return
        }
        #expect(days == 7)
        #expect(endsAt == now.addingTimeInterval(7 * Self.day))
    }

    /// The counter rounds up, so the app never says "0 days left" while it still works.
    ///
    /// Rounding down would put a "0" in the header for the last twenty-four hours
    /// of a working trial, which reads as a bug to the user and as a lie to us.
    @Test func theLastPartialDayStillCountsAsOne() {
        let (clock, _) = Self.makeClock()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        clock.startDate(now: start)

        // Four hours left of a seven-day window.
        let nearlyOver = start.addingTimeInterval(7 * Self.day - 4 * 3600)
        #expect(clock.state(lengthInDays: 7, now: nearlyOver) == .active(
            daysRemaining: 1, endsAt: start.addingTimeInterval(7 * Self.day)
        ))
    }

    @Test func theWindowExpiresTheInstantItRunsOut() {
        let (clock, _) = Self.makeClock()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        clock.startDate(now: start)

        #expect(clock.state(lengthInDays: 7, now: start.addingTimeInterval(7 * Self.day)) == .expired)
        #expect(clock.state(lengthInDays: 7, now: start.addingTimeInterval(30 * Self.day)) == .expired)
    }

    /// A length of zero means "no free window", not "an unbounded one".
    ///
    /// It is reachable from the Remote Config console, so it has to mean something
    /// definite rather than falling through the arithmetic.
    @Test func aZeroLengthWindowIsAlreadyOver() {
        let (clock, _) = Self.makeClock()
        #expect(clock.state(lengthInDays: 0) == .expired)
        #expect(clock.state(lengthInDays: -3) == .expired)
    }

    // MARK: - Remote Config

    /// Lengthening the trial in the console gives the days back to people already
    /// counting down, because the length is read fresh rather than frozen at the
    /// anchor.
    @Test func changingTheLengthReopensAWindowThatHadClosed() {
        let (clock, _) = Self.makeClock()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        clock.startDate(now: start)
        let dayEight = start.addingTimeInterval(8 * Self.day)

        #expect(clock.state(lengthInDays: 7, now: dayEight) == .expired)
        #expect(clock.state(lengthInDays: 14, now: dayEight) == .active(
            daysRemaining: 6, endsAt: start.addingTimeInterval(14 * Self.day)
        ))
    }

    /// Shortening it closes the window for someone who was mid-trial, which is the
    /// other half of the same knob and the reason it is worth turning carefully.
    @Test func shorteningTheLengthClosesAWindowThatWasStillOpen() {
        let (clock, _) = Self.makeClock()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        clock.startDate(now: start)
        let dayFive = start.addingTimeInterval(5 * Self.day)

        #expect(clock.state(lengthInDays: 7, now: dayFive) == .active(
            daysRemaining: 2, endsAt: start.addingTimeInterval(7 * Self.day)
        ))
        #expect(clock.state(lengthInDays: 3, now: dayFive) == .expired)
    }
}
