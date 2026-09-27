//
//  MacKeyRouter.swift
//  DubloonMac
//
//  Makes the single-key transport shortcuts work whatever has keyboard focus
//

import AppKit

/// Sends Space, R, L, P, Home and the arrows to the workspace's transport before a focused list can
/// eat them.
///
/// AppKit offers a key to the focused view before it looks for a menu item without modifiers.
/// A table uses letters to jump to rows and the sidebar uses them to jump to games, so with
/// either focused, R switched to Reverse Singing instead of recording. Editors answer their
/// transport keys everywhere, and so does this: the key runs what the Playback menu would. The
/// exceptions are typing into a field, and the arrows while the sidebar has focus,
/// which is how the sidebar is walked with the keyboard.
enum MacKeyRouter {

    private static var monitor: Any?
    @MainActor private static weak var workspace: MacWorkspaceViewModel?

    @MainActor
    static func install(workspace: MacWorkspaceViewModel) {
        self.workspace = workspace
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Local monitors run on the main thread, inside the event loop.
            nonisolated(unsafe) let event = event
            let handled = MainActor.assumeIsolated { route(event) }
            return handled ? nil : event
        }
    }

    @MainActor
    private static func route(_ event: NSEvent) -> Bool {
        // SwiftUI settles a menu item's enabled state when its menu opens. A shortcut pressed
        // without opening the menu would meet the state from the last time it was open, and
        // ⌘E stayed greyed out after switching to a pack. Settle them before AppKit looks.
        if event.modifierFlags.contains(.command) {
            refreshMenus(NSApp.mainMenu)
            return false
        }

        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard modifiers.isEmpty, let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty else {
            return false
        }

        // Only the editing window, and only when nothing is on top of it: Space in a sheet or in
        // Settings belongs to whatever control is there.
        guard let window = event.window, window.identifier?.rawValue.hasPrefix("main") == true,
              window.attachedSheet == nil else { return false }

        let responder = window.firstResponder
        if let text = responder as? NSTextView, text.isEditable { return false }

        let arrows = [NSUpArrowFunctionKey, NSDownArrowFunctionKey, NSLeftArrowFunctionKey, NSRightArrowFunctionKey]
            .map { String(UnicodeScalar($0)!) }
        let isArrow = arrows.contains(key)
        // The sidebar is walked with the arrows; everywhere else they move between lines.
        if isArrow, let list = responder as? NSOutlineView, list.numberOfColumns == 1 { return false }

        guard let transport = workspace?.transport else { return false }

        let action: (@MainActor () -> Void)??
        switch key {
        case " ": action = .some(transport.togglePlay)
        case "r": action = .some(transport.toggleRecord)
        case "l": action = .some(transport.listen)
        case "p": action = .some(transport.playTake)
        case String(UnicodeScalar(NSUpArrowFunctionKey)!): action = .some(transport.previous)
        case String(UnicodeScalar(NSDownArrowFunctionKey)!): action = .some(transport.next)
        case String(UnicodeScalar(NSLeftArrowFunctionKey)!): action = .some(transport.skipBack)
        case String(UnicodeScalar(NSRightArrowFunctionKey)!): action = .some(transport.skipForward)
        case String(UnicodeScalar(NSHomeFunctionKey)!): action = .some(transport.goToStart)
        default: action = nil
        }

        // Not a transport key at all.
        guard let action else { return false }
        // A transport key the workspace has no use for right now: swallowed, rather than let a
        // list turn it into a jump to some row. Arrows fall through to the focused list.
        guard let action else { return !isArrow }
        action()
        return true
    }

    /// What opening each menu would do: SwiftUI brings every item's enabled state up to date.
    @MainActor
    static func refreshMenus(_ menu: NSMenu?) {
        guard let menu else { return }
        menu.delegate?.menuNeedsUpdate?(menu)
        menu.update()
        for item in menu.items { refreshMenus(item.submenu) }
    }
}
