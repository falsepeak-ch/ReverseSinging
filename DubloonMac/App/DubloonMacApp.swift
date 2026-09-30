//
//  DubloonMacApp.swift
//  DubloonMac
//
//  The Mac app: the library window, a window per pack opened on its own, the welcome and
//  shortcuts panels, Settings, and the menu bar.
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
                NSApp.windows.first { MacWindowID.isKind(MacWindowID.main, $0) }?
                    .setContentSize(NSSize(width: 1280, height: 800))
            }
            return
        }
        #endif

        FirebaseApp.configure()
        UsageDataConsent.apply()

        Crashlytics.crashlytics().setCustomValue(Locale.current.identifier, forKey: "locale")
        Crashlytics.crashlytics().setCustomValue("macos", forKey: "platform")
        CrashReporter.shared.log("launch")
        AnalyticsManager.shared.trackAppLaunch()

        // After Firebase: a store that will not start is reported through it.
        AccessController.shared.start()

        BoothCamAnnouncement.shared.resolveAtLaunch()
    }

    /// A pack from Finder's "Open With", a double-click, or a drop on the Dock icon arrives as an
    /// "open documents" Apple event. Taken here rather than through `application(_:open:)`,
    /// which a SwiftUI app with one `Window` is handed with the files already stripped out.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocuments(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    @objc private func handleOpenDocuments(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let list = event.paramDescriptor(forKeyword: keyDirectObject) else { return }
        var urls: [URL] = []
        if list.numberOfItems == 0 {
            if let url = list.fileURLValue { urls.append(url) }
        } else {
            for index in 1...list.numberOfItems {
                if let url = list.atIndex(index)?.fileURLValue { urls.append(url) }
            }
        }
        MainActor.assumeIsolated { MacFileInbox.shared.deliver(urls) }
    }

    /// Closing the last window, library and packs alike, is quitting.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct DubloonMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var delegate

    /// Shared by every window and the menu bar.
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
        Window("Dubloon", id: MacWindowID.main) {
            MacRootView(app: app, workspace: workspace)
                .frame(minWidth: 1180, minHeight: 700)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
        .commands { MacCommands(app: app, workspace: workspace) }

        // A pack in a window of its own. One window per pack: opening the same pack again
        // brings its window forward. Reopened at launch with the rest of the windows.
        WindowGroup(GameMode.dub.title, id: MacWindowID.pack, for: UUID.self) { $packID in
            MacPackWindow(packID: packID, workspace: workspace)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1360, height: 860)
        .windowResizability(.contentMinSize)
        // Opened from the library, not from File ▸ New Window.
        .commandsRemoved()

        Window(MacStrings.Menu.shortcuts, id: MacWindowID.shortcuts) {
            MacShortcutsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commandsRemoved()

        Window(Strings.Onboarding.welcomeTitle, id: MacWindowID.welcome) {
            MacWelcomeWindow(app: app)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commandsRemoved()

        Settings {
            MacSettingsView(app: app)
        }
    }
}

/// The library window's root: the workspace, the welcome window on first run, and what
/// `ContentView` does around the iPhone's menu. Its paywall, links and open-counting.
struct MacRootView: View {
    @ObservedObject var app: AppViewModel
    @ObservedObject var workspace: MacWorkspaceViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MacWorkspaceView(app: app, workspace: workspace)
            .appLifecycle(app: app)
            .onAppear {
                workspace.openWindow = openWindow
                if !app.hasCompletedOnboarding { openWindow(id: MacWindowID.welcome) }
                MacKeyRouter.install()
                // Tab walks every pane SwiftUI builds, not only the ones it knew at first.
                for window in NSApp.windows { window.autorecalculatesKeyViewLoop = true }
            }
            .onReceive(MacFileInbox.shared.$pending) { url in
                guard let url else { return }
                MacFileInbox.shared.pending = nil
                app.pendingDubImportURL = url
            }
            #if DEBUG
            .task { await MacE2ERunner.runIfRequested(app: app, workspace: workspace) }
            .task { await MacShotPoser.runIfRequested(workspace: workspace) }
            #endif
            .preferredColorScheme(.dark)
    }
}
