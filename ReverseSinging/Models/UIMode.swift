//
//  UIMode.swift
//  ReverseSinging
//
//  Created by Claude Code
//

import Foundation

/// Represents the user interface mode preference
enum UIMode: String, Codable, CaseIterable {
    case simple = "simple"
    case complex = "complex"

    var displayName: String {
        switch self {
        case .simple:
            return Strings.Settings.Mode.simpleName
        case .complex:
            return Strings.Settings.Mode.complexName
        }
    }

    var description: String {
        switch self {
        case .simple:
            return Strings.Settings.Mode.simpleDescription
        case .complex:
            return Strings.Settings.Mode.complexDescription
        }
    }

    /// SF Symbol for the compact menu row. The illustrated asset below is for the Settings
    /// screen, where there is room for it; a menu row wants a symbol.
    var menuSymbol: String {
        switch self {
        case .simple:
            return "square.grid.2x2"
        case .complex:
            return "waveform"
        }
    }

    var settingsAssetName: String {
        switch self {
        case .simple:
            return "settings-simple"
        case .complex:
            return "settings-complex"
        }
    }
}
