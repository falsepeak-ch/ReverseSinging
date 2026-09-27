//
//  MacCommands.swift
//  DubloonMac
//
//  The menu bar: files, the workspaces, the transport, and the ways to support the app.
//

import SwiftUI

/// The full menu bar of an editing suite: File for packs, sessions and export, View for the
/// workspaces, the viewer, the timeline and the panels, a Playback menu for the transport, and
/// Help with the list of shortcuts. Everything the window does has a place here and a key, so
/// it can be found, and so it works without a pointer.
struct MacCommands: Commands {
    @ObservedObject var app: AppViewModel
    @ObservedObject var workspace: MacWorkspaceViewModel
    @Environment(\.openURL) private var openURL

    var body: some Commands {
        SidebarCommands()
        ToolbarCommands()

        // The library window is reopened from the Window menu, and a pack gets its own window
        // from Open in New Window; there is no blank "New Window".
        CommandGroup(replacing: .newItem) {
            Button(Strings.Main.newSession) { workspace.newSession() }
                .keyboardShortcut("n")

            Button(MacStrings.Menu.importPack) { workspace.requestImport() }
                .keyboardShortcut("o")

            OpenInNewWindowMenuItem(workspace: workspace)

            OpenRecentMenu(workspace: workspace)
        }

        CommandGroup(after: .importExport) {
            ExportMenuItem()
        }

        // Edit ▸ Delete… for the pack or session selected in the sidebar.
        CommandGroup(after: .pasteboard) {
            DeleteMenuItem(workspace: workspace)

            Divider()

            Button(MacStrings.Menu.find) { workspace.focusSearch() }
                .keyboardShortcut("f")
        }

        CommandGroup(before: .sidebar) {
            Button(GameMode.reverse.title) { workspace.select(.reverse) }
                .keyboardShortcut("1")
            Button(GameMode.dub.title) { workspace.select(.dubLibrary) }
                .keyboardShortcut("2")
            Button(GameMode.imitate.title) { workspace.select(.imitate) }
                .keyboardShortcut("3")

            Divider()

            ViewerMenu()
            ZoomMenuItems()

            Divider()

            InspectorMenuItem()

            Divider()
        }

        CommandMenu(MacStrings.Menu.playback) {
            PlaybackMenu()
        }

        CommandGroup(replacing: .help) {
            ShortcutsMenuItem()

            Divider()

            Button(Strings.ReviewBanner.rate) {
                openURL(ReviewBanner.writeReviewURL)
            }

            Button(Strings.Settings.privacyPolicy) {
                openURL(URL(string: "https://falsepeak.ch/privacy")!)
            }
        }
    }
}

// MARK: - Menu Contents

// Views rather than inline buttons: a view inside a menu watches the hub and redraws when the
// front window's transport changes, where the `Commands` body itself does not reliably.

private struct PlaybackMenu: View {
    @ObservedObject private var hub = MacTransportHub.shared

    var body: some View {
        let transport = hub.current

        Button(MacStrings.Menu.playPause) { transport.togglePlay?() }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(transport.togglePlay == nil)

        Button(transport.isRecording ? Strings.Dub.stop : MacStrings.Menu.record) { transport.toggleRecord?() }
            .keyboardShortcut("r", modifiers: [])
            .disabled(transport.toggleRecord == nil)

        Divider()

        Button(MacStrings.Menu.listen) { transport.listen?() }
            .keyboardShortcut("l", modifiers: [])
            .disabled(transport.listen == nil)

        Button(MacStrings.Menu.playTake) { transport.playTake?() }
            .keyboardShortcut("p", modifiers: [])
            .disabled(transport.playTake == nil)

        Divider()

        Button(MacStrings.Menu.previousLine) { transport.previous?() }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(transport.previous == nil)

        Button(MacStrings.Menu.nextLine) { transport.next?() }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(transport.next == nil)

        Divider()

        Button(MacStrings.Menu.skipBack) { transport.skipBack?() }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(transport.skipBack == nil)

        Button(MacStrings.Menu.skipForward) { transport.skipForward?() }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(transport.skipForward == nil)

        Button(MacStrings.Menu.goToStart) { transport.goToStart?() }
            .keyboardShortcut(.home, modifiers: [])
            .disabled(transport.goToStart == nil)

        Divider()

        Button(transport.isBoothOn ? Strings.Booth.turnOff : Strings.Booth.turnOn) { transport.toggleBooth?() }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(transport.toggleBooth == nil)
    }
}

private struct ViewerMenu: View {
    @ObservedObject private var hub = MacTransportHub.shared

    var body: some View {
        let transport = hub.current
        Menu(MacStrings.Menu.viewer) {
            ForEach(Array(DubViewerMode.allCases.enumerated()), id: \.element) { index, mode in
                Toggle(isOn: Binding(
                    get: { transport.viewerMode == mode },
                    set: { _ in transport.setViewerMode?(mode) }
                )) {
                    Text(mode.title)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .control])
            }
        }
        .disabled(transport.setViewerMode == nil)
    }
}

private struct ZoomMenuItems: View {
    @ObservedObject private var hub = MacTransportHub.shared

    var body: some View {
        let transport = hub.current
        Button(MacStrings.Menu.zoomIn) { transport.zoomIn?() }
            .keyboardShortcut("=")
            .disabled(transport.zoomIn == nil)
        Button(MacStrings.Menu.zoomOut) { transport.zoomOut?() }
            .keyboardShortcut("-")
            .disabled(transport.zoomOut == nil)
    }
}

private struct OpenRecentMenu: View {
    @ObservedObject var workspace: MacWorkspaceViewModel

    var body: some View {
        let recents = workspace.recentPacks
        Menu(MacStrings.Menu.openRecent) {
            ForEach(recents) { pack in
                Button(pack.title) { workspace.select(.pack(pack.id)) }
            }
            if !recents.isEmpty {
                Divider()
                Button(MacStrings.Menu.clearRecent) { workspace.clearRecents() }
            }
        }
        .disabled(recents.isEmpty)
    }
}

private struct DeleteMenuItem: View {
    @ObservedObject var workspace: MacWorkspaceViewModel

    var body: some View {
        Button(MacStrings.Menu.deleteEllipsis) { workspace.requestDeleteSelection() }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(!canDelete)
    }

    private var canDelete: Bool {
        switch workspace.selection {
        case .pack, .session: true
        default: false
        }
    }
}

private struct ExportMenuItem: View {
    @ObservedObject private var hub = MacTransportHub.shared

    var body: some View {
        Button(MacStrings.Menu.export) { hub.current.export?() }
            .keyboardShortcut("e")
            .disabled(hub.current.export == nil)
    }
}

private struct InspectorMenuItem: View {
    @ObservedObject private var hub = MacTransportHub.shared

    var body: some View {
        let transport = hub.current
        Button(transport.isInspectorShown ? MacStrings.Menu.hideInspector : MacStrings.Menu.showInspector) {
            transport.toggleInspector?()
        }
        .keyboardShortcut("i", modifiers: [.command, .option])
        .disabled(transport.toggleInspector == nil)
    }
}

/// The selected pack, out of the library and into a window of its own.
private struct OpenInNewWindowMenuItem: View {
    @ObservedObject var workspace: MacWorkspaceViewModel

    var body: some View {
        Button(MacStrings.Menu.openInNewWindow) {
            if let id = workspace.selectedPackID { workspace.openInNewWindow(id) }
        }
        .keyboardShortcut("o", modifiers: [.command, .option])
        .disabled(workspace.selectedPackID == nil)
    }
}

private struct ShortcutsMenuItem: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(MacStrings.Menu.shortcuts) { openWindow(id: MacWindowID.shortcuts) }
            .keyboardShortcut("/")
    }
}
