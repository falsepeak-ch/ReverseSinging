//
//  DubStarterPacks.swift
//  ReverseSinging
//
//  The two scenes that ship with the app
//

import Foundation

/// Installs the scenes bundled with the app, once.
///
/// The dub mode is worth nothing on an empty shelf: a new player opens it, finds a screen
/// telling them to go and find a pack somewhere, and leaves. These two are written and
/// generated for this app — original characters, original dialogue, generated voices,
/// generated pictures — so there is always something to dub the moment the mode is opened.
///
/// They arrive as ordinary `.zip` packs and go in through `DubPackImporter`, the same path a
/// pack the user found themselves takes. Nothing about them is special once installed: they
/// can be played, exported and deleted like any other.
nonisolated enum DubStarterPacks {

    /// Bundled zips, by resource name. Order is install order, which is reverse display
    /// order — the library sorts newest first, so the last one installed is the one on top.
    static let bundled = ["TheYogurtIncident", "TheLastSlice"]

    private static let installedKey = "dub.starterPacksInstalled"

    /// Names already installed at some point.
    ///
    /// Remembered so a user who deletes a starter pack keeps it deleted. Re-adding it on
    /// every launch would make the delete button look broken.
    private static var installed: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: installedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: installedKey) }
    }

    /// The bundled packs that have never been installed on this device.
    static var pending: [String] {
        let done = installed
        return bundled.filter { !done.contains($0) && url(for: $0) != nil }
    }

    private static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "zip")
    }

    /// Imports one pending pack and remembers it.
    ///
    /// Marked as installed whether or not the import succeeded. A bundled zip that will not
    /// parse is broken in the build, not on the device, and retrying it on every launch would
    /// only spend the user's battery finding that out again.
    @discardableResult
    static func install(_ name: String) async -> DubPack? {
        defer { installed.insert(name) }

        guard let url = url(for: name) else { return nil }

        do {
            return try await DubPackImporter.shared.importPack(from: url)
        } catch {
            print("⚠️ Starter pack \(name) could not be installed: \(error.localizedDescription)")
            return nil
        }
    }

    #if DEBUG
    /// Lets a test start from a clean device without touching `UserDefaults` by hand.
    static func forgetInstallsForTesting() {
        UserDefaults.standard.removeObject(forKey: installedKey)
    }
    #endif
}
