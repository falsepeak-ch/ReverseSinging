//
//  DubloonMacApp.swift
//  DubloonMac
//
//  The Mac app: the same menu and games as the iPhone, in one window, plus a Settings window.
//

import SwiftUI
import TipKit
import FirebaseCore
import FirebaseCrashlytics

/// What the iPhone's `AppDelegate` does at launch, in the same order and for the same reasons.
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // A screenshot run is not a session, and must never meet a paywall.
        if ScreenshotMode.isActive {
            AccessController.shared.start()
            // The Mac App Store takes 2560×1600: a 1280×800-point window on a Retina screen.
            // Set here rather than trusted to `defaultSize`, which a remembered frame beats.
            DispatchQueue.main.async {
                NSApp.windows.first?.setContentSize(NSSize(width: 1280, height: 800))
            }
            return
        }
        #endif

        FirebaseApp.configure()

        Crashlytics.crashlytics().setCustomValue(Locale.current.identifier, forKey: "locale")
        Crashlytics.crashlytics().setCustomValue("macos", forKey: "platform")
        CrashReporter.shared.log("launch")
        AnalyticsManager.shared.trackAppLaunch()

        // After Firebase: the trial length and the paywall switches come from Remote Config.
        AccessController.shared.start()

        BoothCamAnnouncement.shared.resolveAtLaunch()
    }

    /// One window: closing it is quitting, as it is for any single-window Mac app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct DubloonMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var delegate

    /// Shared by the game window and the Settings window, so a change in one shows in the other.
    @StateObject private var app = AppViewModel()

    init() {
        AudioSessionManager.shared.configure()
        SoundManager.shared.preload()
        DubContentGate.clearLegacyOwnershipFlag()

        #if DEBUG
        if ScreenshotMode.isActive { Tips.hideAllTipsForTesting() }
        #endif
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        Window("Dubloon", id: "main") {
            ContentView(app: app)
                // Wide enough for a scene and its waveform: the record and playback screens open
                // as sheets over this window and must fit inside it.
                .frame(minWidth: 860, minHeight: 720)
                // The shared screens were drawn for iOS, where a bare `Button` has no bezel.
                // On the Mac it gets one, so any button that does not pick a style draws only
                // its label.
                .buttonStyle(.plain)
        }
        // Each screen's own header is the title bar, as the top of the screen is on iPhone.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 820)
        .windowResizability(.contentMinSize)
        .commands { MacCommands(app: app) }

        Settings {
            SettingsView(app: app)
                .frame(width: 480, height: 640)
                .buttonStyle(.plain)
        }
    }
}
