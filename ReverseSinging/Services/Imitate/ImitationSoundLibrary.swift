//
//  ImitationSoundLibrary.swift
//  ReverseSinging
//
//  The bundled sounds the Sound Imitation game asks people to copy
//

import Foundation

/// How the library is grouped on screen.
nonisolated enum ImitationCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case animals
    case vehicles
    case cartoon
    case human

    var id: String { rawValue }

    var title: String {
        switch self {
        case .animals: return Strings.Imitate.Category.animals
        case .vehicles: return Strings.Imitate.Category.vehicles
        case .cartoon: return Strings.Imitate.Category.cartoon
        case .human: return Strings.Imitate.Category.human
        }
    }
}

/// One sound to imitate, as listed in `imitation-sounds.json`.
///
/// Every clip is CC0 from Freesound; `freesoundID` and `author` are kept so provenance is
/// answerable even though the licence asks for nothing. Built by
/// `Local/Tools/ImitationSounds/fetch_sounds.py`.
nonisolated struct ImitationSound: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let category: ImitationCategory
    let emoji: String
    /// 1 easy … 3 hard. Shown as dots on the tile.
    let difficulty: Int
    let file: String
    let duration: TimeInterval
    let freesoundID: Int
    let author: String
    let license: String

    /// The sound's name in the user's language.
    var name: String { Strings.Imitate.soundName(id) }

    /// Custom illustrations for the animal library; other categories retain their glyphs.
    var artworkName: String? {
        guard category == .animals else { return nil }
        return "imitate-\(id)"
    }

    /// The clip in the app bundle. The bundle is flat, which is why every file carries the
    /// `imitate-` prefix.
    var url: URL? {
        let base = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return Bundle.main.url(forResource: base, withExtension: ext)
    }
}

/// The sounds that ship with the app.
nonisolated enum ImitationSoundLibrary {

    static let manifestName = "imitation-sounds"

    /// Every sound, in manifest order. Empty only if the bundle is broken, which a test checks.
    static let all: [ImitationSound] = load()

    static func sounds(in category: ImitationCategory) -> [ImitationSound] {
        all.filter { $0.category == category }
    }

    static func sound(id: String) -> ImitationSound? {
        all.first { $0.id == id }
    }

    private static func load() -> [ImitationSound] {
        guard let url = Bundle.main.url(forResource: manifestName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let sounds = try? JSONDecoder().decode([ImitationSound].self, from: data)
        else { return [] }
        return sounds
    }
}
