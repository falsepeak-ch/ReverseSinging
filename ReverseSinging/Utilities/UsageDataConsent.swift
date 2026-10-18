//
//  UsageDataConsent.swift
//  ReverseSinging
//
//  The Share Usage Data switch: whether anonymous statistics and crash reports leave the device
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

/// Whether this device sends Firebase Analytics events and Crashlytics reports. On unless the
/// person turns it off in Settings; the Privacy Policy points them there.
///
/// The purchase check keeps running either way: the app needs it to know what is unlocked,
/// and it does not report on what anyone does.
nonisolated enum UsageDataConsent {

    static let key = "privacy.shareUsageData"

    static var isGranted: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    /// Whether crashes and non-fatals reach Crashlytics. Never from a Debug build: a Simulator
    /// or Xcode run is not a player, and it has no dSYM, so all it adds is a crash nobody can
    /// read and a "Missing (required)" row in the console.
    static var sendsCrashReports: Bool {
        #if DEBUG
        // Except a `-crashTest crash|send` run, whose whole point is to see a report arrive.
        return UserDefaults.standard.string(forKey: "crashTest") != nil
        #else
        return isGranted
        #endif
    }

    /// Tells Firebase what the switch says. Called right after `FirebaseApp.configure()`, and
    /// again whenever the switch moves.
    static func apply() {
        Analytics.setAnalyticsCollectionEnabled(isGranted)
        let sendsCrashes = sendsCrashReports
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(sendsCrashes)
        if !sendsCrashes {
            // A crash from before the switch went off, still waiting to be sent, stays here.
            Crashlytics.crashlytics().deleteUnsentReports()
        }
    }

    static func set(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: key)
        apply()
    }
}
