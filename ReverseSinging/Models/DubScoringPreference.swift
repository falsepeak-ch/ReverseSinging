//
//  DubScoringPreference.swift
//  ReverseSinging
//
//  Whether takes are marked against the original
//

import Foundation
import Combine

/// Whether the dub mode scores the user's takes.
///
/// **Off by default, and deliberately so.** Dubbing a scene badly is most of the fun, and a
/// grade attached to every attempt turns a game people play for the silly voices into a test
/// they can fail. Someone who wants to be measured can turn it on; nobody has it done to them.
///
/// Modelled on `HeadphoneMonitor`: an observable singleton over one `UserDefaults` key, so
/// every screen reads the same answer and redraws the moment it changes.
@MainActor
final class DubScoringPreference: ObservableObject {

    static let shared = DubScoringPreference()

    private static let enabledKey = "dub.scoringEnabled"

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    private init() {
        // `bool(forKey:)` is false for a key that was never written, which is the default
        // we want. No migration and no first-run special case.
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    #if DEBUG
    /// Lets a test drive the preference without reaching into `UserDefaults`.
    func setForTesting(_ enabled: Bool) { isEnabled = enabled }
    #endif
}
