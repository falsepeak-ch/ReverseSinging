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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
