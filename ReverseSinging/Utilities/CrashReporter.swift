//
//  CrashReporter.swift
//  ReverseSinging
//
//  Crash and non-fatal error reporting
//

import Foundation
import FirebaseCrashlytics

/// Everything that reaches Crashlytics goes through here.
///
/// Crashlytics picks up actual crashes by itself once `FirebaseApp.configure()` has run, so
/// that half needs no code. What it cannot see is this app's far more common failure: an
/// import, a transcode, an export or a recording that throws, gets turned into a sentence on
/// screen or a `print`, and is then forgotten. Nobody files those, so they are reported here
/// as non-fatals instead. A pack format we never anticipated shows up as a cluster rather
/// than as a one-star review saying "doesn't work".
///
/// What is deliberately *not* sent: anything from a recording, a take, or the contents of a
/// file. The store listing promises audio never leaves the device, and a crash report is
/// still leaving the device. Errors are reported by their type and their own message, which
/// for the app's `LocalizedError`s is a string we wrote ourselves.
///
/// `nonisolated` deliberately: the failures worth reporting happen on whatever thread the
/// work was on. A transcode runs on a detached task and a starter-pack install is nonisolated,
/// so a main-actor reporter would either not compile against them or, worse, hop actors and
/// report after the state it was describing had already moved on.
nonisolated final class CrashReporter {
    static let shared = CrashReporter()

    private init() {}

    /// The one place that can turn reporting off, mirroring `AnalyticsManager`.
    ///
    /// A screenshot run drives the app through seven locales from a cold launch and trips
    /// error paths on purpose. `ReverseSingingApp` already skips `FirebaseApp.configure()`
    /// in that mode, so this is belt and braces, but it keeps the rule in one readable place.
    private var isEnabled: Bool {
        #if DEBUG
        return !ScreenshotMode.isActive
        #else
        return true
        #endif
    }

    // MARK: - Context

    /// Where in the app the user was. Read on the next crash *and* attached to every
    /// non-fatal, which is what turns "an export failed" into "an export failed, on a pack
    /// with 42 lines, after 3 takes".
    enum Key: String {
        case gameMode = "game_mode"
        case screen
        case packLineCount = "pack_line_count"
        case packRecordedCount = "pack_recorded_count"
        case packHasVideo = "pack_has_video"
        case lineIndex = "line_index"
    }

    func set(_ key: Key, _ value: Any) {
        guard isEnabled else { return }
        Crashlytics.crashlytics().setCustomValue(value, forKey: key.rawValue)
    }

    /// A breadcrumb. Crashlytics keeps the last of these and ships them with the next
    /// report, so the log is the sequence of steps that led into the failure.
    func log(_ message: String) {
        guard isEnabled else { return }
        Crashlytics.crashlytics().log(message)
    }

    // MARK: - Non-Fatals

    /// Reports an error that the app handled and carried on from.
    ///
    /// `context` is what separates otherwise identical `NSError`s: a Core Audio failure
    /// during a transcode and the same code during a mixdown are two different bugs, and
    /// without this they land in one issue.
    func record(_ error: Error, context: String, keys: [String: Any] = [:]) {
        guard isEnabled else { return }

        var info: [String: Any] = [
            "context": context,
            // `localizedDescription` for the app's own error types is a string from
            // Localizable.strings, so this reads as the sentence the user was shown.
            NSLocalizedDescriptionKey: error.localizedDescription
        ]
        for (key, value) in keys {
            info[key] = value
        }

        let reported = error as NSError
        Crashlytics.crashlytics().record(
            error: NSError(domain: reported.domain, code: reported.code, userInfo: info)
        )
    }

    /// A failure with no `Error` behind it. Guard statements that fall through, and the
    /// `else` branches that used to be a lone `print`, have nothing to throw.
    func recordFailure(_ context: String, reason: String, keys: [String: Any] = [:]) {
        guard isEnabled else { return }

        var info: [String: Any] = [
            "context": context,
            NSLocalizedDescriptionKey: reason
        ]
        for (key, value) in keys {
            info[key] = value
        }

        Crashlytics.crashlytics().record(
            error: NSError(domain: "com.falsepeak.dubloon", code: 1, userInfo: info)
        )
    }
}
