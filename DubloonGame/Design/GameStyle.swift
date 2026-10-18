//
//  GameStyle.swift
//  DubloonGame
//
//  The game-show palette and type, taken from the voxhop game kit's artwork.
//

import SwiftUI
import CoreText

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
    /// Chunky, rounded: reads as a game rather than as the editor. For running text.
    static func game(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// The show's lettering, for titles, buttons and scores (`GameFont`).
    static func gameDisplay(_ size: CGFloat) -> Font {
        Font(GameFont.display(size: size) as CTFont)
    }
}

/// The bundled display faces, both SIL OFL (licences in `DesignAssets/game-font`).
///
/// Lilita One is the cartoon title face but only covers Western European Latin, so the
/// languages it cannot spell (Czech, Polish, Catalan, Turkish, Greek, Cyrillic, Japanese)
/// get M PLUS Rounded 1c Black, which can. Arabic and Thai, which neither has, keep the
/// system's rounded heavy weight.
enum GameFont {
    private static let files = ["LilitaOne-Regular", "MPLUSRounded1c-Black"]
    private static let lilitaLanguages: Set<String> = ["en", "de", "es", "fr", "it", "nl", "da", "sv", "nb", "fi", "pt"]

    /// Registers the faces for this process. Call once, before the first view.
    static func register() {
        for file in files {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// The face for the language the app is running in, nil for the system's.
    static let displayName: String? = {
        let language = Bundle.main.preferredLocalizations.first?.split(separator: "-").first.map(String.init) ?? "en"
        if lilitaLanguages.contains(language) { return "LilitaOne" }
        if language == "ar" || language == "th" { return nil }
        return "RoundedMplus1c-Black"
    }()

    static func display(size: CGFloat) -> UIFont {
        if let name = displayName, let font = UIFont(name: name, size: size) { return font }
        let base = UIFont.systemFont(ofSize: size, weight: .black)
        return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
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
        /// The game's "dubloon" wordmark (DesignAssets/game-logo), the logo used everywhere.
        static let logo = "game-logo"
    }

    /// The animation kit's stage props and effects.
    enum Props {
        static let atlas = "Props"
        static let prize = "game-prop-prize"
        static let note = "game-prop-note"
        static let ribbon = "game-prop-ribbon"
        static let micStand = "game-prop-mic-stand"
        static let spotlight = "game-prop-spotlight"
        static func sparkle(_ frame: Int) -> String { "game-fx-sparkle-\(frame)" }
        static func speaker(_ frame: Int) -> String { "game-prop-speaker-\(frame)" }
    }

    /// The kit's rating stars, as plain images so SwiftUI and SpriteKit both draw them.
    enum Rating {
        static let filled = "game-star-filled"
        static let empty = "game-star-empty"
        static let half = "game-star-half"
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
