//
//  FirstLaunchDate.swift
//  ReverseSinging
//
//  When this install was first opened, as far as the device can tell.
//

import Foundation

/// The app's own record of when it was first launched on this device.
///
/// It is one of the dates the About screen's "Member since" is read from; see
/// `AccessController.memberSince`.
///
/// Written once and never rewritten. An install from the days when the app gave a
/// free trial is dated from that trial's start, which is the earliest moment the
/// app is known to have been open, rather than from the launch that happened to
/// ship this.
///
/// It dies with the app container, so a reinstall looks like a first launch.
nonisolated struct FirstLaunchDate {

    static let key = "firstLaunch.date"

    /// Where builds that had a free trial recorded its start. Only ever read.
    static let legacyTrialStartKey = "trial.startedAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The recorded date, or nil before `record` has run.
    var date: Date? {
        defaults.object(forKey: Self.key) as? Date
    }

    /// Records the date if there is none yet. Called once per launch, first thing.
    @discardableResult
    func record(now: Date = Date()) -> Date {
        if let date { return date }

        let trialStart = defaults.object(forKey: Self.legacyTrialStartKey) as? Date
        // Never later than now: a date left by a clock that has since moved back
        // would otherwise date this install in the future.
        let recorded = min(trialStart ?? now, now)
        defaults.set(recorded, forKey: Self.key)
        return recorded
    }
}
