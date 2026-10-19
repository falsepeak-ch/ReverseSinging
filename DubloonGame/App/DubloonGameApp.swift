//
//  DubloonGameApp.swift
//  DubloonGame
//
//  Dubloon the Game: the dub and sound-imitation games, presented as a game show.
//

import SwiftUI
import TipKit
import FirebaseCore
import FirebaseCrashlytics

/// The same launch work as the iPhone app's delegate, less what only that app has: there is
/// no earlier version of this one to announce Booth Cam to.
final class GameAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        #if DEBUG
        // A screenshot run is not a session, and must never meet a paywall.
        if ScreenshotMode.isActive {
            AccessController.shared.start()
            return true
        }
        #endif

        FirebaseApp.configure()
        // Before anything is logged: someone who switched Share Usage Data off sends nothing.
        UsageDataConsent.apply()

        Crashlytics.crashlytics().setCustomValue(Locale.current.identifier, forKey: "locale")
        CrashReporter.shared.log("launch")
        AnalyticsManager.shared.trackAppLaunch()

        // Remote off switches for promotional banners; see `BannerSwitches`.
        BannerSwitches.shared.start()

        #if DEBUG
        // `-crashTest crash`: crashes a few seconds in, to check reports reach Crashlytics. Launch
        // without the debugger, which would catch it, then with `-crashTest send` to send it (a
        // Debug build otherwise sends nothing, and drops what is waiting).
        if UserDefaults.standard.string(forKey: "crashTest") == "crash" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { fatalError("Crashlytics test crash") }
        }
        #endif

        // After Firebase, so a store that will not start is reported.
        AccessController.shared.start()
        return true
    }
}

@main
struct DubloonGameApp: App {
    @UIApplicationDelegateAdaptor(GameAppDelegate.self) var delegate

    init() {
        AudioSessionManager.shared.configure()
        SoundManager.shared.preload()
        GameSFXPlayer.shared.preload()
        GameFont.register()
        Task { await HostClipLibrary.preload() }

        #if DEBUG
        if ScreenshotMode.isActive { Tips.hideAllTipsForTesting() }
        #endif

        // The dub game's first-run tips; see `ReverseSingingApp` for why they are immediate.
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            GameContentView()
        }
    }
}
