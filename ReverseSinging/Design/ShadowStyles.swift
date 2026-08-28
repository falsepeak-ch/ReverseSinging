//
//  ShadowStyles.swift
//  ReverseSinging
//
//  Premium shadow and elevation system
//

import SwiftUI

// MARK: - Shadow Styles

enum ShadowStyle {
    case subtle
    case card
    case elevated
    case floating

    var radius: CGFloat {
        switch self {
        case .subtle: return 4
        case .card: return 8
        case .elevated: return 12
        case .floating: return 20
        }
    }

    var offset: CGSize {
        switch self {
        case .subtle: return CGSize(width: 0, height: 1)
        case .card: return CGSize(width: 0, height: 2)
        case .elevated: return CGSize(width: 0, height: 4)
        case .floating: return CGSize(width: 0, height: 8)
        }
    }

    /// Deliberately faint: separation in this design comes from the surface ramp and
    /// hairline strokes, not from blur. Shadows only lift true overlays off the canvas.
    var opacity: Double {
        switch self {
        case .subtle: return 0
        case .card: return 0
        case .elevated: return 0.25
        case .floating: return 0.45
        }
    }
}

// MARK: - View Extension

extension View {
    func cardShadow(_ style: ShadowStyle = .card) -> some View {
        self.shadow(
            color: Color.black.opacity(style.opacity),
            radius: style.radius,
            x: style.offset.width,
            y: style.offset.height
        )
    }
}
