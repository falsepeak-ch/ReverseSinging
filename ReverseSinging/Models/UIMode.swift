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

    var icon: String {
        switch self {
        case .simple:
            return "rectangle.3.group"
        case .complex:
            return "rectangle.grid.2x2"
        }
    }
}
