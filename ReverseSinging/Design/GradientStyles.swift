//
//  GradientStyles.swift
//  ReverseSinging
//
//  Voxxa-inspired gradient design system
//

import SwiftUI

extension LinearGradient {
    // MARK: - Primary Gradients (Cyan → Purple)

    /// Main gradient: Cyan to Purple (like Voxxa buttons)
    static let voxxaPrimary = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.85, blue: 1.0),    // Cyan #00D9FF
            Color(red: 0.66, green: 0.33, blue: 0.97)   // Purple #A855F7
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Adaptive Premium Gradients

    /// Premium adaptive button gradient with sophisticated color balance
    static func voxxaPrimaryAdaptive(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            // Dark mode: Rich 3-color gradient for premium feel
            return LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.75, blue: 0.95),   // Deep electric blue
                    Color(red: 0.58, green: 0.40, blue: 0.92),  // Rich royal purple
                    Color(red: 0.82, green: 0.32, blue: 0.88)   // Deep magenta accent
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            // Light mode: Darker, saturated 2-color gradient
            return LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.55, blue: 0.75),   // Deep cyan
                    Color(red: 0.48, green: 0.25, blue: 0.82)   // Deep purple
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    /// Vertical primary gradient
    static let voxxaPrimaryVertical = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.85, blue: 1.0),
            Color(red: 0.66, green: 0.33, blue: 0.97)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Secondary Gradients (Blue → Pink)

    /// Secondary gradient: Blue to Pink
    static let voxxaSecondary = LinearGradient(
        colors: [
            Color(red: 0.23, green: 0.51, blue: 0.96),  // Blue #3B82F6
            Color(red: 0.93, green: 0.28, blue: 0.60)   // Pink #EC4899
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Vertical secondary gradient
    static let voxxaSecondaryVertical = LinearGradient(
        colors: [
            Color(red: 0.23, green: 0.51, blue: 0.96),
            Color(red: 0.93, green: 0.28, blue: 0.60)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Icon Background Gradients

    /// Large circular icon background (diagonal)
    static let voxxaIconCircle = LinearGradient(
        colors: [
            Color(red: 0.4, green: 0.6, blue: 0.9),     // Light blue
            Color(red: 0.7, green: 0.5, blue: 0.9)      // Light purple
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Microphone icon gradient
    static let voxxaMicrophone = LinearGradient(
        colors: [
            Color(red: 0.5, green: 0.7, blue: 1.0),     // Sky blue
            Color(red: 0.8, green: 0.5, blue: 0.95)     // Lavender
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Recording state gradient (more intense)
    static let voxxaRecording = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.85, blue: 1.0),    // Cyan
            Color(red: 0.93, green: 0.28, blue: 0.60)   // Pink
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Subtle Gradients

    /// Very subtle background gradient
    static let voxxaBackgroundSubtle = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.04, blue: 0.06),  // Very dark blue-black
            Color(red: 0.02, green: 0.02, blue: 0.04)   // Pure black
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card overlay gradient (for glassmorphism)
    static let voxxaGlassOverlay = LinearGradient(
        colors: [
            Color.white.opacity(0.1),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Radial Gradients

extension RadialGradient {
    /// Glowing effect for icons
    static func voxxaGlow(color: Color) -> RadialGradient {
        RadialGradient(
            colors: [
                color.opacity(0.4),
                color.opacity(0.0)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }

    /// Icon background with center glow
    static let voxxaIconGlow = RadialGradient(
        colors: [
            Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.3),
            Color.clear
        ],
        center: .center,
        startRadius: 20,
        endRadius: 120
    )
}

// MARK: - Gradient View Modifiers

extension View {
    /// Apply Voxxa primary gradient as foreground
    func voxxaGradientForeground() -> some View {
        self.overlay(LinearGradient.voxxaPrimary)
            .mask(self)
    }

    /// Apply gradient glow effect
    func voxxaGlow(color: Color = Color(red: 0.66, green: 0.33, blue: 0.97)) -> some View {
        self
            .shadow(color: color.opacity(0.5), radius: 20, x: 0, y: 10)
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}
