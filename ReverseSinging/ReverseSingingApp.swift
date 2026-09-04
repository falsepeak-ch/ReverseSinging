//
//  ReverseSingingApp.swift
//  ReverseSinging
//
//  Created by Josep Bordes Jové on 20/10/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        #if DEBUG
        // A screenshot run is not a session. Configuring Firebase here would put
        // seven synthetic launches a locale into the real analytics.
        if ScreenshotMode.isActive {
            // Still started, so it settles on "unlocked" rather than on the
            // default state. A capture must never meet a paywall.
            AccessController.shared.start()
            return true
        }
        #endif

        FirebaseApp.configure()

        // Crashlytics is on from here. It catches the crashes by itself; the non-fatals it
        // cannot see are reported through `CrashReporter` from the paths that swallow them.
        Crashlytics.crashlytics().setCustomValue(
            Locale.current.identifier, forKey: "locale"
        )
        CrashReporter.shared.log("launch")

        // Track app launch
        AnalyticsManager.shared.trackAppLaunch()

        // Configures RevenueCat and starts the entitlement stream. Here rather
        // than in `App.init()`, which SwiftUI runs *before* this method: the
        // trial length comes from Remote Config, and Remote Config needs the
        // `FirebaseApp` configured above.
        AccessController.shared.start()

        return true
    }
}

@main
struct ReverseSingingApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        // Configure audio session on app launch to prevent conflicts
        AudioSessionManager.shared.configure()

        // Decode the interface sounds up front so the first clapper isn't late
        SoundManager.shared.preload()

        // The dub gate no longer remembers a "yes"; drop what 1.3.0 wrote.
        DubContentGate.clearLegacyOwnershipFlag()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
