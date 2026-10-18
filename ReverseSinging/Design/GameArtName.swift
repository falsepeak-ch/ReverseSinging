//
//  GameArtName.swift
//  ReverseSinging
//
//  Which drawing a shared screen shows: the studio's, or the game's outlined version of it.
//

import Foundation

/// Shared modals show an illustration from the studio's set. Dubloon the Game has outlined
/// versions of the same objects (`game-<name>`), drawn like the rest of its art, and uses them
/// in place of the studio ones.
nonisolated enum GameArtName {
    static func object(_ name: String) -> String {
        #if DUBLOON_GAME
        "game-\(name)"
        #else
        name
        #endif
    }
}
