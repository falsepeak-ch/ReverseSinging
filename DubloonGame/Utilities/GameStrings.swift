//
//  GameStrings.swift
//  DubloonGame
//
//  The game's own copy. Everything else is the shared `Strings`.
//

import Foundation

nonisolated enum GameStrings {
    private static func string(_ key: String, _ comment: String) -> String {
        NSLocalizedString(key, tableName: "Game", comment: comment)
    }

    enum Host {
        static let greeting = string("game.host.greeting", "What the game-show host says on the home stage, in a speech panel above the two games")
        static let outOfTakes = string("game.host.outOfTakes", "What the host says on the home stage once the free takes are used up")
    }

    enum Imitate {
        static let prompt = string("game.imitate.prompt", "Big caption on the stage before the first attempt at a sound")
    }

    enum Dub {
        /// Takes the line number and the scene's line count.
        static func lineOf(_ line: Int, _ total: Int) -> String {
            String(format: string("game.dub.lineOf", "Which line of the scene is up, e.g. 'Line 2 of 6'"), line, total)
        }
    }

    static let pickSound = string("game.pickSound", "Title of the screen where the player picks a sound to imitate")
    static let pickScene = string("game.pickScene", "Title of the screen where the player picks a movie scene to dub")
    static let nextSound = string("game.nextSound", "Button after a result: go on to the next sound")
    /// Through the 3-2-1, before the mic opens.
    static let getReady = string("game.getReady", "Big caption on the stage during the 3-2-1 count before recording")

    /// The brand line under "Dubloon" at the top of the stage.
    static let subtitle = string("game.subtitle", "Under the app name on the home stage: 'Dubloon' / 'The Game'")
}
