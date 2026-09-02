//
//  DubStarterPacks.swift
//  ReverseSinging
//
//  The two scenes that ship with the app: one animated, one classic
//

import Foundation

/// Installs the scenes bundled with the app, once.
///
/// The dub mode is worth nothing on an empty shelf: a new player opens it, finds a screen
/// telling them to go and find a pack somewhere, and leaves. Two are there so the mode always
/// opens onto something to perform. Deliberately one of each kind, because the two kinds
/// play completely differently. *Camp Rules* is a modern CG comedy with big performances to
/// copy; *Stuck Up* is black-and-white 1951 dialogue where the fun is the flat period delivery.
/// A third would have been a second helping of one of them.
///
/// They rest on **two different kinds of claim**, and the difference matters more than the
/// scenes do:
///
/// - *Camp Rules* is cut from **Sprite Fright** (Blender Studio, 2021) under **CC BY 4.0**,
///   an affirmative licence from the rights holder, which holds in every territory the app
///   ships to. The condition is credit.
/// - *Stuck Up* is cut from **The Outsider** (Centron Productions, 1951), whose US copyright
///   was never renewed in its 28th year. That is an *absence* rather than a permission, and it
///   is a **US finding only**. The position elsewhere is unresolved. What was checked, and how
///   far it goes, is written down in `Local/Tools/DubPacks/PD_SHORTLIST.md` (not tracked, see `.gitignore`).
///
/// Either way the pack states its own provenance: `build_clip_pack.py` writes `source`,
/// `source_url` and `rights` into `_pack_info.ini`, `DubPackParser` reads them, and both the
/// pack detail screen and the notice before every export print them. For *Camp Rules* that is
/// the licence condition being discharged, not decoration.
///
/// Using real film rather than a generated scene is what makes them worth shipping: the words,
/// the timing and the mouths saying them were recorded together, so the picture cannot drift
/// against the reference the performer is copying. It is also why no scene here has two
/// characters talking at once. A finished mix cannot be split into one chunk per speaker, and
/// cutting overlapping dialogue out of it would carry the same audio twice.
///
nonisolated enum DubStarterPacks {

    /// Bundled zips, by resource name. Order is install order, which is reverse display
    /// order. The library sorts newest first, so the last one installed is the one on top.
    /// *Camp Rules* stays on top: it is the shorter of the two and the easier to finish.
    static let bundled = ["StuckUp", "CampRules"]

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
            // A bundled zip that will not parse is broken in the build we shipped, and the
            // mode opens onto an empty shelf for every user on that build. There is no
            // screen that reports it, so this non-fatal is the only alarm.
            CrashReporter.shared.record(
                error,
                context: "dub_pack.starter_install",
                keys: ["pack": name]
            )
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
