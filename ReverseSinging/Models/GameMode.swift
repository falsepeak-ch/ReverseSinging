//
//  GameMode.swift
//  ReverseSinging
//
//  The games the app ships.
//

import Foundation

/// The games on offer. The home screen lists these; picking one pushes into it.
enum GameMode: String, CaseIterable, Identifiable, Hashable {
    case reverse
    case dub
    case imitate

    var id: String { rawValue }

    /// Asset-catalog images rather than SF Symbols. Reverse singing takes the boom mic
    /// rather than the desk mic, because the desk mic is the one in the Dubloon logo
    /// right above this list, and the same drawing twice on one screen reads as a mistake.
    var image: String {
        switch self {
        case .reverse: return "studio-mic-boom"
        case .dub: return "clapperboard"
        case .imitate: return "megaphone"
        }
    }

    var title: String {
        switch self {
        case .reverse: return Strings.Main.Mode.reverseTitle
        case .dub: return Strings.Main.Mode.dubTitle
        case .imitate: return Strings.Main.Mode.imitateTitle
        }
    }

    var subtitle: String {
        switch self {
        case .reverse: return Strings.Main.Mode.reverseSubtitle
        case .dub: return Strings.Main.Mode.dubSubtitle
        case .imitate: return Strings.Main.Mode.imitateSubtitle
        }
    }
}
