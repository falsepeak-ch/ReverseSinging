//
//  GameShot.swift
//  DubloonGame
//
//  Debug-only: open a screen straight from launch, for App Store screenshots in every language.
//

import Foundation

#if DEBUG
/// `-gameShot home|scenes|dub|sounds|imitate` opens that screen at launch, so a script can
/// capture each locale's screenshots without tapping through the game. Tips and the reminder
/// card stay out of the way while it is set.
enum GameShot: String {
    case home, scenes, dub, sounds, imitate

    static var current: GameShot? {
        UserDefaults.standard.string(forKey: "gameShot").flatMap(GameShot.init(rawValue:))
    }

    var opensScenes: Bool { self == .scenes || self == .dub }
    var opensSounds: Bool { self == .sounds || self == .imitate }
}
#endif
