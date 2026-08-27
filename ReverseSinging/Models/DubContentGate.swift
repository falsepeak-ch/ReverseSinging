//
//  DubContentGate.swift
//  ReverseSinging
//
//  Gate shown before every dub import: the app never ships, hosts or
//  distributes movies, so the user has to bring their own files, and the
//  question, the disclaimers and the pointer to where files come from are worth
//  repeating rather than answering once and burying.
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

/// The gate itself, which remembers nothing.
///
/// It used to: a "yes, I already have them" was persisted and the gate skipped
/// itself forever after, which meant the rights disclaimer and the pointer to
/// where files come from were visible to a user exactly once. Both belong in
/// front of every import, so the flag is gone.
///
/// Devices updating from 1.3.0 still carry the old key. It is cleared at launch,
/// not because a stale bool does any harm sitting there, but so that a future
/// read of it cannot quietly resurrect the skip on precisely the installs that
/// have been dubbing the longest.
enum DubContentGate {
    private static let legacyOwnershipKey = "dubContentGate.hasConfirmedOwnership"

    static func clearLegacyOwnershipFlag() {
        UserDefaults.standard.removeObject(forKey: legacyOwnershipKey)
    }

    #if DEBUG
    static func setLegacyOwnershipFlagForTesting() {
        UserDefaults.standard.set(true, forKey: legacyOwnershipKey)
    }

    static var legacyOwnershipFlagIsSetForTesting: Bool {
        UserDefaults.standard.object(forKey: legacyOwnershipKey) != nil
    }
    #endif
}
