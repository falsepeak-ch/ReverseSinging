//
//  BoothCamPreference.swift
//  ReverseSinging
//
//  Whether the front camera films the performer during a take
//

import Foundation
import Combine

/// Whether dubbing also films the performer, and how that footage is shown back to them.
///
/// **Off by default, and it stays off until the user says otherwise.** A camera is not a
/// preference of the same weight as a click sound: nothing here turns on because a screen was
/// opened, and `hasSeenPrimer` exists so the app makes its own case once, in its own words,
/// before iOS shows the system prompt.
///
/// Modelled on `DubScoringPreference`: an observable singleton over `UserDefaults`, so every
/// screen reads the same answer and redraws the moment it changes.
@MainActor
final class BoothCamPreference: ObservableObject {

    static let shared = BoothCamPreference()

    private static let enabledKey = "booth.enabled"
    private static let mirrorKey = "booth.mirrorPreview"
    private static let seenPrimerKey = "booth.hasSeenPrimer"

    /// Whether a take also rolls the front camera.
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    /// Whether the on-screen monitor is flipped. The preview only: the file written to disk
    /// is never mirrored, so text in shot reads the right way round for whoever watches it.
    @Published var mirrorsPreview: Bool {
        didSet { UserDefaults.standard.set(mirrorsPreview, forKey: Self.mirrorKey) }
    }

    /// Whether the explanation has been shown. Set once the user has answered it either way,
    /// so backing out of the primer is not punished by seeing it again on the next line.
    @Published private(set) var hasSeenPrimer: Bool {
        didSet { UserDefaults.standard.set(hasSeenPrimer, forKey: Self.seenPrimerKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        // `bool(forKey:)` is false for a key that was never written, which is the default we
        // want for both the feature and the primer. No migration, no first-run special case.
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        hasSeenPrimer = defaults.bool(forKey: Self.seenPrimerKey)
        // The one setting whose default is on: a selfie preview that is not mirrored reads as
        // broken to anyone who has ever used a front camera.
        mirrorsPreview = defaults.object(forKey: Self.mirrorKey) as? Bool ?? true
    }

    func markPrimerSeen() { hasSeenPrimer = true }

    #if DEBUG
    /// Lets a test drive the preference without reaching into `UserDefaults`.
    func setForTesting(enabled: Bool, mirrors: Bool = true, seenPrimer: Bool = true) {
        isEnabled = enabled
        mirrorsPreview = mirrors
        hasSeenPrimer = seenPrimer
    }
    #endif
}
