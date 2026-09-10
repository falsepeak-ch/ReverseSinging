//
//  BoothCamAnnouncement.swift
//  ReverseSinging
//
//  Whether the people who updated need telling that the booth exists
//

import Foundation

/// Decides who sees the note about Booth Cam, and remembers once they have.
///
/// Someone who has been dubbing since 1.3 updates, opens the app and sees the screens they
/// always did. The camera key is one more glyph in a HUD they stopped reading months ago, and
/// the primer behind it only appears to people who tap it. Left to themselves, most of them
/// would never learn the app can film them. So an update gets one note, once.
///
/// A fresh install gets nothing: onboarding and the record screen's own tips cover it, and a
/// "what's new" on a first launch announces a change to someone with nothing to compare it to.
///
/// Told apart the way `EarlyAdopter` tells its users apart: by what was on the device at the
/// first launch of this build, decided once and written down. Five minutes later a new user
/// has completed onboarding too, and the two are indistinguishable.
struct BoothCamAnnouncement {

    static let shared = BoothCamAnnouncement()

    private enum Key {
        /// Whether the question has been asked. Guards against asking twice.
        static let decided = "announce.booth.decided"
        /// Whether the note is still owed.
        static let due = "announce.booth.due"
    }

    /// Written by `AudioViewModel` when onboarding finishes. Present means the app was in
    /// use before this build arrived.
    private static let onboardingMarker = "hasCompletedOnboarding"

    /// Written by `BoothCamPreference` once the primer has been answered. A tester who has
    /// already met the booth does not need it announced.
    private static let primerMarker = "booth.hasSeenPrimer"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Deciding

    /// Answers the question from what is already on the device. Called once, at launch,
    /// before the first screen writes anything.
    func resolveAtLaunch() {
        guard !defaults.bool(forKey: Key.decided) else { return }
        defaults.set(true, forKey: Key.decided)

        let wasInUse = defaults.bool(forKey: Self.onboardingMarker)
        let hasMetTheBooth = defaults.bool(forKey: Self.primerMarker)
        defaults.set(wasInUse && !hasMetTheBooth, forKey: Key.due)
    }

    // MARK: - Reading

    var isDue: Bool { defaults.bool(forKey: Key.due) }

    func markShown() {
        defaults.set(false, forKey: Key.due)
    }

    // MARK: - Testing

    #if DEBUG
    /// Puts the decision back so the launch path can be exercised again.
    func resetForTesting() {
        [Key.decided, Key.due].forEach(defaults.removeObject(forKey:))
    }
    #endif
}
