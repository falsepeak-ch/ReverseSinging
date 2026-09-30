//
//  MacShortcutsView.swift
//  DubloonMac
//
//  Help ▸ Keyboard Shortcuts: every key the app answers, grouped the way the menus are, in a
//  panel that can stay open beside the work
//

import SwiftUI
import TipKit

/// The list a keyboard-first app owes its users: each shortcut with its keys drawn as keycaps,
/// in the order the menu bar has them. Its own window rather than a sheet, so it can be kept
/// open next to a pack while the keys are learned.
struct MacShortcutsView: View {
    @Environment(\.dismissWindow) private var dismissWindow

    private struct Shortcut: Identifiable {
        let title: String
        let keys: [String]
        var id: String { title }
    }

    private struct Group: Identifiable {
        let title: String
        let shortcuts: [Shortcut]
        var id: String { title }
    }

    private var groups: [Group] {
        [
            Group(title: MacStrings.Menu.playback, shortcuts: [
                Shortcut(title: MacStrings.Menu.playPause, keys: ["Space"]),
                Shortcut(title: MacStrings.Menu.record, keys: ["R"]),
                Shortcut(title: MacStrings.Menu.listen, keys: ["L"]),
                Shortcut(title: MacStrings.Menu.playTake, keys: ["P"]),
                Shortcut(title: MacStrings.Menu.previousLine, keys: ["↑"]),
                Shortcut(title: MacStrings.Menu.nextLine, keys: ["↓"]),
                Shortcut(title: MacStrings.Menu.skipBack, keys: ["←"]),
                Shortcut(title: MacStrings.Menu.skipForward, keys: ["→"]),
                Shortcut(title: MacStrings.Menu.goToStart, keys: ["↖"]),
                Shortcut(title: Strings.Booth.settingsTitle, keys: ["⇧", "⌘", "C"])
            ]),
            Group(title: MacStrings.Shortcuts.view, shortcuts: [
                Shortcut(title: GameMode.reverse.title, keys: ["⌘", "1"]),
                Shortcut(title: GameMode.dub.title, keys: ["⌘", "2"]),
                Shortcut(title: GameMode.homeVideo.title, keys: ["⌘", "3"]),
                Shortcut(title: GameMode.imitate.title, keys: ["⌘", "4"]),
                Shortcut(title: "\(MacStrings.Menu.viewer): \(MacStrings.Panel.line)", keys: ["⌃", "⌘", "1"]),
                Shortcut(title: "\(MacStrings.Menu.viewer): \(Strings.Dub.original)", keys: ["⌃", "⌘", "2"]),
                Shortcut(title: "\(MacStrings.Menu.viewer): \(Strings.Dub.myDub)", keys: ["⌃", "⌘", "3"]),
                Shortcut(title: MacStrings.Menu.zoomIn, keys: ["⌘", "="]),
                Shortcut(title: MacStrings.Menu.zoomOut, keys: ["⌘", "-"]),
                Shortcut(title: MacStrings.Panel.inspector, keys: ["⌥", "⌘", "I"]),
                Shortcut(title: MacStrings.Search.prompt, keys: ["⌘", "F"])
            ]),
            Group(title: MacStrings.Shortcuts.file, shortcuts: [
                Shortcut(title: Strings.Main.newSession, keys: ["⌘", "N"]),
                Shortcut(title: MacStrings.Menu.importPack, keys: ["⌘", "O"]),
                Shortcut(title: MacStrings.Menu.openInNewWindow, keys: ["⌥", "⌘", "O"]),
                Shortcut(title: MacStrings.Menu.export, keys: ["⌘", "E"]),
                Shortcut(title: MacStrings.Menu.deleteEllipsis, keys: ["⌘", "⌫"]),
                Shortcut(title: MacStrings.Menu.shortcuts, keys: ["⌘", "/"])
            ])
        ]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title)
                        .editorLabelStyle(.rsTextTertiary)
                        .padding(.bottom, 2)
                    ForEach(group.shortcuts) { shortcut in
                        HStack(spacing: 12) {
                            Text(shortcut.title)
                                .font(.system(size: 12))
                                .foregroundColor(.rsTextPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            HStack(spacing: 3) {
                                ForEach(shortcut.keys, id: \.self) { key in
                                    Keycap(label: key)
                                }
                            }
                        }
                    }
                }
                .frame(width: 250, alignment: .leading)
            }
        }
        .padding(24)
        .fixedSize()
        .background(Color.rsSurface1)
        // Esc closes the panel, as it would a sheet.
        .background {
            Button("") { dismissWindow(id: MacWindowID.shortcuts) }
                .keyboardShortcut(.cancelAction)
                .hidden()
        }
        .preferredColorScheme(.dark)
        .onAppear { MacShortcutsTip().invalidate(reason: .actionPerformed) }
    }
}

/// A key drawn as a key.
private struct Keycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.rsTextPrimary)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.rsSurface3))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.rsStrokeStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
    }
}

// MARK: - Tip

/// Shown once, on the dashboard: this app is meant to be played from the keyboard.
struct MacShortcutsTip: Tip {
    var title: Text { Text(MacStrings.Shortcuts.tipTitle) }
    var message: Text? { Text(MacStrings.Shortcuts.tipMessage) }
    var image: Image? { Image(systemName: "keyboard") }
}
