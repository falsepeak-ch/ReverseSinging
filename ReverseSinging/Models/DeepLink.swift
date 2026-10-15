//
//  DeepLink.swift
//  ReverseSinging
//
//  The dubloon:// links the App Store's custom product pages and events open
//

import Foundation

/// A `dubloon://` link, parsed. Each one names the screen a store page or an event promised:
///
/// - `dubloon://game/movie-dub`, `reverse-singing`, `sound-imitation`, `home-video-dub`
/// - `dubloon://event/spooky`, Spooky Voice Week, which opens Sound Imitation
///
/// Anything else under the scheme parses to nil and the app simply opens. A file URL, a dub
/// pack handed in from Files or AirDrop, is never a deep link.
enum DeepLink: Equatable {
    case game(GameMode)

    static let scheme = "dubloon"

    /// The event slugs, and the game each one opens.
    private static let events: [String: GameMode] = [
        "spooky": SpookyVoiceWeek.destination,
    ]

    /// The game slugs the store pages use, which are not `GameMode`'s raw values.
    private static let games: [String: GameMode] = [
        "movie-dub": .dub,
        "reverse-singing": .reverse,
        "sound-imitation": .imitate,
        "home-video-dub": .homeVideo,
    ]

    /// Whether the URL is ours at all, known path or not.
    static func isDeepLinkURL(_ url: URL) -> Bool {
        !url.isFileURL && url.scheme?.lowercased() == scheme
    }

    init?(url: URL) {
        guard Self.isDeepLinkURL(url) else { return nil }

        // `dubloon://game/movie-dub` puts "game" in the host; `dubloon:///game/movie-dub`
        // and `dubloon:game/movie-dub` put it in the path. Read both the same way.
        var parts = url.pathComponents.filter { $0 != "/" }
        if let host = url.host(), !host.isEmpty { parts.insert(host, at: 0) }
        if parts.isEmpty, let opaque = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path {
            parts = opaque.split(separator: "/").map(String.init)
        }
        parts = parts.map { $0.lowercased() }

        guard parts.count >= 2 else { return nil }
        switch parts[0] {
        case "game":
            guard let mode = Self.games[parts[1]] else { return nil }
            self = .game(mode)
        case "event":
            guard let mode = Self.events[parts[1]] else { return nil }
            self = .game(mode)
        default:
            return nil
        }
    }

    /// What the link opens, for analytics.
    var gameMode: GameMode {
        switch self {
        case .game(let mode): mode
        }
    }
}
