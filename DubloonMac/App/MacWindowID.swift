//
//  MacWindowID.swift
//  DubloonMac
//
//  The app's windows by name, for opening them and for telling them apart
//

import AppKit

/// The scene identifiers. SwiftUI names each window after its scene's identifier ("pack-…"
/// for every pack window), which is how AppKit-side code tells one kind from another.
enum MacWindowID {
    /// The library: sidebar, and a workspace for whatever it has selected.
    static let main = "main"
    /// One dub pack, open on its own.
    static let pack = "pack"
    static let shortcuts = "shortcuts"
    static let welcome = "welcome"

    /// A window that plays and records, and so answers the transport keys.
    static func isEditing(_ window: NSWindow) -> Bool {
        guard let identifier = window.identifier?.rawValue else { return false }
        return identifier.hasPrefix(main) || identifier.hasPrefix(pack)
    }

    static func isKind(_ kind: String, _ window: NSWindow) -> Bool {
        window.identifier?.rawValue.hasPrefix(kind) == true
    }
}
