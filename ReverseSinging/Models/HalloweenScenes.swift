//
//  HalloweenScenes.swift
//  ReverseSinging
//
//  Scary movie scenes to dub for Halloween, picked from GameBanana's Dub Mode packs and listed
//  at the top of the dub library while the Halloween banner is switched on.
//

import Foundation

/// One horror scene someone has packed for dubbing on GameBanana.
///
/// The app hosts none of them: each is a link to the pack's own GameBanana page, where the
/// player downloads it themself, and the usual import gate still stands in front of the
/// picker. Film titles stay in English, as the packs are named.
struct HalloweenScene: Identifiable, Hashable {
    /// The GameBanana mod id.
    let id: Int
    let film: String
    let scene: String

    var url: URL { URL(string: "https://gamebanana.com/mods/\(id)")! }
}

enum HalloweenScenes {

    /// Picked 2026-10-19 from GameBanana's Dub Mode category (game 20674): English, live,
    /// with a .zip download, from horror films rather than series or games.
    static let all: [HalloweenScene] = [
        HalloweenScene(id: 703918, film: "The Shining", scene: "Here's Johnny!"),
        HalloweenScene(id: 712863, film: "The Shining", scene: "The baseball bat"),
        HalloweenScene(id: 709484, film: "Scream (1996)", scene: "Tatum and Ghostface"),
        HalloweenScene(id: 714964, film: "Scream 4", scene: "The killer reveal"),
        HalloweenScene(id: 709391, film: "Child's Play 2", scene: "Chucky's spell fails"),
        HalloweenScene(id: 728015, film: "Child's Play", scene: "Chucky and John Bishop"),
        HalloweenScene(id: 703716, film: "Coraline", scene: "Coraline vs the Other Mother"),
    ]

    /// The list shows exactly when the Halloween banner may: Remote Config's
    /// `halloween_banner_enabled` is on and the deal's two weeks are running. Unlike the
    /// banner it does not wait for the store or hide after a purchase; Pro players dub too.
    @MainActor
    static func isShown(switches: BannerSwitches = .shared, at now: Date = Date()) -> Bool {
        guard switches.isHalloweenBannerEnabled else { return false }
        #if DEBUG
        // The banner's own debug switch shows the list before the dates too.
        if UserDefaults.standard.bool(forKey: "forceHalloweenOffer") { return true }
        #endif
        return HalloweenOffer.isRunning(at: now)
    }
}
