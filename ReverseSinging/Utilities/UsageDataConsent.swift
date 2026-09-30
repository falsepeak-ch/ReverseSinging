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

    /// Tells Firebase what the switch says. Called right after `FirebaseApp.configure()`, and
    /// again whenever the switch moves.
    static func apply() {
        let granted = isGranted
        Analytics.setAnalyticsCollectionEnabled(granted)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(granted)
        if !granted {
            // A crash from before the switch went off, still waiting to be sent, stays here.
            Crashlytics.crashlytics().deleteUnsentReports()
        }
    }

    static func set(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: key)
        apply()
    }
}
