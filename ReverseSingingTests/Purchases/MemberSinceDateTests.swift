//
//  MemberSinceDateTests.swift
//  ReverseSingingTests
//
//  The dates "Member since" is read from: the app's first launch, and the store's download date
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Member Since Dates")
struct MemberSinceDateTests {

    private func makeDefaults() -> UserDefaults {
        let name = "MemberSinceDateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
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

    /// An install from the days of the free trial is dated from the trial's start, not from
    /// the launch that shipped this.
    @Test func anInstallThatHadATrialIsDatedFromItsStart() {
        let defaults = makeDefaults()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(start, forKey: FirstLaunchDate.legacyTrialStartKey)

        let recorded = FirstLaunchDate(defaults: defaults).record(now: start.addingTimeInterval(86_400 * 10))

        #expect(recorded == start)
    }

    /// A trial start left by a clock that has since moved back must not date the install in
    /// the future.
    @Test func aFutureTrialStartIsNotBelieved() {
        let defaults = makeDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(now.addingTimeInterval(86_400 * 365), forKey: FirstLaunchDate.legacyTrialStartKey)

        #expect(FirstLaunchDate(defaults: defaults).record(now: now) == now)
    }

    // MARK: - The sandbox's placeholder date

    /// Sandbox and TestFlight report every download as 2013-08-01, twelve years before the
    /// app existed.
    @Test func sandboxPlaceholderIsNotADownloadDate() {
        let sandbox = Date(timeIntervalSince1970: 1_375_315_200)
        #expect(AccessController.plausibleDownloadDate(sandbox) == nil)
    }

    @Test func dateBeforeTheStoreDebutIsNotADownloadDate() {
        let dayBefore = AccessController.storeDebut.addingTimeInterval(-1)
        #expect(AccessController.plausibleDownloadDate(dayBefore) == nil)
    }

    @Test func realDownloadDatesPassThrough() {
        let later = AccessController.storeDebut.addingTimeInterval(86_400 * 300)
        #expect(AccessController.plausibleDownloadDate(AccessController.storeDebut) == AccessController.storeDebut)
        #expect(AccessController.plausibleDownloadDate(later) == later)
        #expect(AccessController.plausibleDownloadDate(nil) == nil)
    }
}
