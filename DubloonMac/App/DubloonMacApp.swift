//
//  DubloonMacApp.swift
//  DubloonMac
//
//  The Mac app: one editing-suite window, the settings window, and the menu bar.
//

import SwiftUI
import TipKit
import FirebaseCore
import FirebaseCrashlytics

/// What the iPhone's `AppDelegate` does at launch, in the same order and for the same reasons.
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The whole app is a dark room, menus and panels included, like the suites it follows.
        NSApp.appearance = NSAppearance(named: .darkAqua)

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

    /// Shared by the window, the Settings window and the menu bar.
    @StateObject private var app = AppViewModel()
    @StateObject private var workspace = MacWorkspaceViewModel()

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
            MacRootView(app: app, workspace: workspace)
                .frame(minWidth: 1180, minHeight: 700)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
        .commands { MacCommands(app: app, workspace: workspace) }

        Settings {
            MacSettingsView(app: app)
        }
    }
}

/// The window's root: the workspace, the welcome sheet on first run, and what `ContentView`
/// does around the iPhone's menu. Its paywall, links and open-counting.
struct MacRootView: View {
    @ObservedObject var app: AppViewModel
    @ObservedObject var workspace: MacWorkspaceViewModel

    var body: some View {
        MacWorkspaceView(app: app, workspace: workspace)
            .sheet(isPresented: Binding(
                get: { !app.hasCompletedOnboarding },
                set: { _ in }
            )) {
                MacWelcomeView(app: app)
                    .interactiveDismissDisabled()
        
            }
            .appLifecycle(app: app)
            .onAppear { MacKeyRouter.install(workspace: workspace) }
            #if DEBUG
            .task { await MacE2ERunner.runIfRequested(app: app, workspace: workspace) }
            #endif
            .preferredColorScheme(.dark)

    }
}
