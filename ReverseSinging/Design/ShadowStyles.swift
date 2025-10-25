//
//  ShadowStyles.swift
//  ReverseSinging
//
//  Premium shadow and elevation system
//

import SwiftUI

// MARK: - Shadow Styles

enum ShadowStyle {
    case none
    case subtle
    case card
    case elevated
    case floating

    var radius: CGFloat {
        switch self {
        case .none: return 0
        case .subtle: return 4
        case .card: return 8
        case .elevated: return 12
        case .floating: return 20
        }
    }

    var offset: CGSize {
        switch self {
        case .none: return .zero
        case .subtle: return CGSize(width: 0, height: 1)
        case .card: return CGSize(width: 0, height: 2)
        case .elevated: return CGSize(width: 0, height: 4)
        case .floating: return CGSize(width: 0, height: 8)
        }
    }

    var opacity: Double {
        switch self {
        case .none: return 0
        case .subtle: return 0.05
        case .card: return 0.08
        case .elevated: return 0.12
        case .floating: return 0.15
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

    func elevatedShadow() -> some View {
        self.cardShadow(.elevated)
    }

    func floatingShadow() -> some View {
        self.cardShadow(.floating)
    }
}

// MARK: - Card Modifier

struct CardStyle: ViewModifier {
    let shadowStyle: ShadowStyle
    let backgroundColor: Color

    init(shadow: ShadowStyle = .card, background: Color = .rsCardBackground) {
        self.shadowStyle = shadow
        self.backgroundColor = background
    }

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .cardShadow(shadowStyle)
    }
}

extension View {
    func cardStyle(shadow: ShadowStyle = .card, background: Color = .rsCardBackground) -> some View {
        modifier(CardStyle(shadow: shadow, background: background))
    }
}

// MARK: - Glassmorphism (Voxxa-inspired)

struct GlassmorphicCard: ViewModifier {
    let blurRadius: CGFloat
    let backgroundColor: Color
    let borderOpacity: Double

    init(
        blur: CGFloat = 10,
        background: Color = Color.rsCardBackground,
        borderOpacity: Double = 0.2
    ) {
        self.blurRadius = blur
        self.backgroundColor = background
        self.borderOpacity = borderOpacity
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Glassmorphic background with blur
                    backgroundColor
                        .background(.ultraThinMaterial)

                    // Subtle gradient overlay
                    LinearGradient.voxxaGlassOverlay
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                // Subtle border
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

extension View {
    /// Apply glassmorphic card style (Voxxa-inspired)
    func glassCard(
        blur: CGFloat = 10,
        background: Color = .rsCardBackground,
        borderOpacity: Double = 0.2
    ) -> some View {
        modifier(GlassmorphicCard(blur: blur, background: background, borderOpacity: borderOpacity))
    }
}

// MARK: - Gradient Circle Background (for icons)

struct GradientCircleBackground: ViewModifier {
    let gradient: LinearGradient
    let size: CGFloat

    init(gradient: LinearGradient = .voxxaIconCircle, size: CGFloat = 160) {
        self.gradient = gradient
        self.size = size
    }

    func body(content: Content) -> some View {
        ZStack {
            // Gradient circle
            Circle()
                .fill(gradient)
                .frame(width: size, height: size)
                .shadow(color: Color.rsGradientPurple.opacity(0.3), radius: 30, x: 0, y: 15)

            // Icon content
            content
        }
    }
}

extension View {
    /// Wrap in gradient circle (for icon backgrounds like Voxxa)
    func gradientCircle(
        gradient: LinearGradient = .voxxaIconCircle,
        size: CGFloat = 160
    ) -> some View {
        modifier(GradientCircleBackground(gradient: gradient, size: size))
    }
}
