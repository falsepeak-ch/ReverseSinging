//
//  DubContentGate.swift
//  ReverseSinging
//
//  Gate shown before the dubbing module: the app never ships, hosts or
//  distributes movies, so the user has to bring their own files.
//

import Foundation

/// A third-party place where people find movie files to dub.
///
/// The app has no relationship with these sites: they are shown purely as an
/// example of where the files usually come from, and every download is the
/// user's own responsibility.
struct DubContentSource: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL

    /// Displayed host, e.g. `gamebanana.com`
    var host: String {
        url.host()?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }

    static let example = DubContentSource(
        id: "gamebanana-movies",
        name: "GameBanana",
        url: URL(string: "https://gamebanana.com/mods/cats/48023")!
    )
}

/// Remembers whether the user already told us they have their movies on device,
/// so the gate is only shown until they confirm once.
enum DubContentGate {
    private static let confirmedKey = "dubContentGate.hasConfirmedOwnership"

    static var hasConfirmedOwnership: Bool {
        get { UserDefaults.standard.bool(forKey: confirmedKey) }
        set { UserDefaults.standard.set(newValue, forKey: confirmedKey) }
    }

    /// Shows the gate again on the next entry to the dubbing module.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: confirmedKey)
    }
}
