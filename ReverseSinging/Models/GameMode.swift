//
//  GameMode.swift
//  ReverseSinging
//
//  The two games the app ships.
//

import Foundation

/// The games on offer. The home screen lists these; picking one pushes into it.
enum GameMode: String, CaseIterable, Identifiable, Hashable {
    case reverse
    case dub

    var id: String { rawValue }

    /// Asset-catalog images rather than SF Symbols. The illustrated mic and
    /// clapperboard are what the rest of the interface uses for these two games.
    var image: String {
        switch self {
        case .reverse: return "microphone"
        case .dub: return "clapperboard"
        }
    }

    var title: String {
        switch self {
        case .reverse: return Strings.Main.Mode.reverseTitle
        case .dub: return Strings.Main.Mode.dubTitle
        }
    }

    var subtitle: String {
        switch self {
        case .reverse: return Strings.Main.Mode.reverseSubtitle
        case .dub: return Strings.Main.Mode.dubSubtitle
        }
    }
}
