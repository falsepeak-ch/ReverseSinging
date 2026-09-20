//
//  FirstLaunchDate.swift
//  ReverseSinging
//
//  When this install was first opened, as far as the device can tell.
//

import Foundation
import DubloonFoundation

/// The app's own record of when it was first launched on this device.
///
/// It exists for one job: standing in for the App Store's download date when the
/// store will not report one, so that someone who plainly arrived after the
/// paywall's cutoff is not let through for good on a technicality. See
/// `PaywallEligibility` for how little it is trusted.
///
/// Written once and never rewritten. An install that was already counting down a
/// trial before this existed is dated from that trial's anchor, which is the
/// earliest moment the app is known to have been open, rather than from the
/// launch that happened to ship this.
///
/// It dies with the app container, so a reinstall looks like a first launch. That
/// is exactly why it is only ever the fallback: the receipt follows the Apple
/// Account, and this does not.
nonisolated struct FirstLaunchDate {

    static let key = "firstLaunch.date"

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

        let trialAnchor = defaults.object(forKey: TrialClock.defaultStartKey) as? Date
        // Never later than now: an anchor from a clock that has since moved back
        // would otherwise date this install in the future.
        let recorded = min(trialAnchor ?? now, now)
        defaults.set(recorded, forKey: Self.key)
        return recorded
    }
}
