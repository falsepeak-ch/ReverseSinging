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
        if ScreenshotMode.isActive { return true }
        #endif

        FirebaseApp.configure()

        // Track app launch
        AnalyticsManager.shared.trackAppLaunch()

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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
