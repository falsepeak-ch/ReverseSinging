//
//  GameStyle.swift
//  DubloonGame
//
//  The game-show palette and type, taken from the voxhop game kit's artwork.
//

import SwiftUI

extension Color {
    /// The kit's outline colour: every panel, button and tile is drawn with it.
    static let gameNavy = Color(gameHex: 0x0C2233)
    /// The dialogue panel's face.
    static let gameIvory = Color(gameHex: 0xFBF6EA)
    /// The primary button's fill.
    static let gameCyan = Color(gameHex: 0x5FD3F3)
    /// The stage's accent stripe.
    static let gameCoral = Color(gameHex: 0xE8584A)

    /// The kit's colours are drawn into its art, so they are fixed rather than light-and-dark.
    init(gameHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    /// Chunky, rounded: reads as a game rather than as the editor.
    static func game(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// The kit's art, by atlas and texture name, so a renamed file is a one-line change.
///
/// The textures are prepared for SpriteKit: cropped to their content and stored at @3x, sized
/// in points so the nine-sliced panel and button keep their corners at the size they are drawn.
enum GameArt {
    static let stage = "game-stage"

    enum Host: String, CaseIterable {
        case idle = "game-host-idle"
        case blink = "game-host-blink"
        case talk = "game-host-talk"
        case delight = "game-host-delight"
    }

    enum UI {
        static let atlas = "UI"
        static let panel = "game-panel-dialogue"
        static let button = "game-button-primary"
        static let star = "game-fx-star"
    }

    static let hostAtlas = "Host"
    static let gamesAtlas = "Games"

    static func tile(for mode: GameMode) -> String {
        switch mode {
        case .imitate: return "game-tile-imitate"
        default: return "game-tile-dub"
        }
    }
}
