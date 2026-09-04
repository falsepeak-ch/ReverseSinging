//
//  TrialClock.swift
//  ReverseSinging
//
//  How long the free window has left to run.
//

import Foundation

/// Where a trial stands right now.
nonisolated enum TrialState: Equatable {
    /// Still running. `daysRemaining` is what the counter shows, and it counts the
    /// day in progress: it reads `1` right up until the window actually closes,
    /// never `0` while the app is still usable.
    case active(daysRemaining: Int, endsAt: Date)
    /// The window has closed.
    case expired
}

/// The free window, measured from the first launch of the build that introduced it.
///
/// The anchor is written the first time it is read and never rewritten, so the
/// clock starts on first launch rather than on install or on purchase date. That
/// choice matters for the users already on 1.3.2: they have no anchor, so the
/// first launch of the version that ships this gives them the whole window
/// instead of finding it already spent.
///
/// The anchor is a local timestamp, so it trusts the device clock, and moving the
/// clock backwards extends the trial. That is deliberate: the alternative is a
/// server round-trip on every launch to answer a question worth a few days of a
/// one-off purchase. What it must not do is *shorten*, which is why a stored
/// anchor in the future is clamped rather than believed.
struct TrialClock {

    static let shared = TrialClock()

    private static let startKey = "trial.startedAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Anchor

    /// The moment the window opened, seeded on first read.
    ///
    /// A stored value later than `now` means the device clock moved backwards
    /// since it was written; it is re-anchored to `now` so the user gets a full
    /// window rather than a negative one.
    @discardableResult
    func startDate(now: Date = Date()) -> Date {
        let stored = defaults.object(forKey: Self.startKey) as? Date

        guard let stored, stored <= now else {
            defaults.set(now, forKey: Self.startKey)
            return now
        }
        return stored
    }

    /// Whether the window has ever been opened on this device.
    ///
    /// Distinct from `startDate`, which opens it. Used by the places that want to
    /// look without starting the count.
    var hasStarted: Bool {
        defaults.object(forKey: Self.startKey) != nil
    }

    // MARK: - State

    /// Where the window stands, given a length that Remote Config may have changed
    /// since the last launch.
    ///
    /// The length is read fresh every time rather than frozen at the anchor, so
    /// lengthening the trial in the console gives the days back to people who are
    /// already counting down.
    func state(lengthInDays: Int, now: Date = Date()) -> TrialState {
        guard lengthInDays > 0 else { return .expired }

        let endsAt = startDate(now: now).addingTimeInterval(TimeInterval(lengthInDays) * 86_400)
        guard endsAt > now else { return .expired }

        // Rounded up: a window with four hours left is "1 day left", not "0".
        let daysRemaining = max(1, Int(ceil(endsAt.timeIntervalSince(now) / 86_400)))
        return .active(daysRemaining: daysRemaining, endsAt: endsAt)
    }

    // MARK: - Testing

    #if DEBUG
    /// Moves the anchor so a debug build can stand at any point in the window.
    func setStartDateForTesting(_ date: Date?) {
        if let date {
            defaults.set(date, forKey: Self.startKey)
        } else {
            defaults.removeObject(forKey: Self.startKey)
        }
    }
    #endif
}
