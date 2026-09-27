//
//  MacCommands.swift
//  DubloonMac
//
//  The menu bar: files, the workspaces, the transport, and the ways to support the app.
//

import SwiftUI

/// The full menu bar of an editing suite: File for packs, sessions and export, View for the
/// workspaces and panels, a Playback menu for the transport, and Help. Every transport key is
/// here as well as on the window, so it can be found, and so it works without a pointer.
struct MacCommands: Commands {
    @ObservedObject var app: AppViewModel
    @ObservedObject var workspace: MacWorkspaceViewModel
    @Environment(\.openURL) private var openURL

    var body: some Commands {
        SidebarCommands()
        ToolbarCommands()

        // One window, reopened from the Window menu; no "New Window".
        CommandGroup(replacing: .newItem) {
            Button(Strings.Main.newSession) { workspace.newSession() }
                .keyboardShortcut("n")

            Button(MacStrings.Menu.importPack) { workspace.requestImport() }
                .keyboardShortcut("o")
        }

        CommandGroup(after: .importExport) {
            ExportMenuItem(workspace: workspace)
        }

        CommandGroup(before: .sidebar) {
            Button(GameMode.reverse.title) { workspace.select(.reverse) }
                .keyboardShortcut("1")
            Button(GameMode.dub.title) { workspace.select(.dubLibrary) }
                .keyboardShortcut("2")
            Button(GameMode.imitate.title) { workspace.select(.imitate) }
                .keyboardShortcut("3")

            Divider()

            InspectorMenuItem(workspace: workspace)

            Divider()
        }

        CommandMenu(MacStrings.Menu.playback) {
            PlaybackMenu(workspace: workspace)
        }

        CommandGroup(replacing: .help) {
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

// Views rather than inline buttons: a view inside a menu watches the workspace and redraws when
// its transport changes, where the `Commands` body itself does not reliably.

private struct PlaybackMenu: View {
    @ObservedObject var workspace: MacWorkspaceViewModel

    var body: some View {
        let transport = workspace.transport

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
    }
}

private struct ExportMenuItem: View {
    @ObservedObject var workspace: MacWorkspaceViewModel

    var body: some View {
        Button(MacStrings.Menu.export) { workspace.transport.export?() }
            .keyboardShortcut("e")
            .disabled(workspace.transport.export == nil)
    }
}

private struct InspectorMenuItem: View {
    @ObservedObject var workspace: MacWorkspaceViewModel

    var body: some View {
        Button(workspace.showsInspector ? MacStrings.Menu.hideInspector : MacStrings.Menu.showInspector) {
            workspace.showsInspector.toggle()
        }
        .keyboardShortcut("i", modifiers: [.command, .option])
    }
}
