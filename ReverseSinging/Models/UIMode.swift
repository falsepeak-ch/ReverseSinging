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
            return "Simple"
        case .complex:
            return "Complex"
        }
    }

    var description: String {
        switch self {
        case .simple:
            return "Large buttons, minimal interface"
        case .complex:
            return "Advanced controls and visualizations"
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
