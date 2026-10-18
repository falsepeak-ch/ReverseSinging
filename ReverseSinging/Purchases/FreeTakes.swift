//
//  FreeTakes.swift
//  ReverseSinging
//
//  How many takes someone without Dubloon Pro has used, across every game.
//

import Foundation

/// The game whose take was counted, for analytics and the paywall's source.
nonisolated enum FreeTakeKind: String {
    /// A recording reversed in Reverse Singing.
    case reverse
    /// A movie line dubbed.
    case dub
    /// A sound imitated.
    case imitate
    /// A take over the user's own video.
    case homeVideo = "home_video"
}

/// Every game is open to everyone, and the first `limit` takes are free, counted together
/// across the games: three lines dubbed, or two lines and a reversed song, use them up. After
/// that the games still open, but a new take asks for Dubloon Pro.
///
/// Counted on the device, like a purchase is remembered there, so the answer needs no network.
/// A reinstall starts the count again; that is accepted rather than fought.
struct FreeTakes {

    nonisolated static let limit = 3

    static let shared = FreeTakes()

    private static let key = "freeTakes.used"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var used: Int { defaults.integer(forKey: Self.key) }

    var remaining: Int { max(0, Self.limit - used) }

    /// Counts one finished take and returns how many have been used.
    @discardableResult
    func recordUse() -> Int {
        let used = used + 1
        defaults.set(used, forKey: Self.key)
        return used
    }

    #if DEBUG
    func resetForTesting() {
        defaults.removeObject(forKey: Self.key)
    }
    #endif
}
