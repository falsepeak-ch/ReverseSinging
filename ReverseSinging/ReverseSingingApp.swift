//
//  ReverseSingingApp.swift
//  ReverseSinging
//
//  Created by Josep Bordes Jové on 20/10/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
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
