//
//  GradientStyles.swift
//  ReverseSinging
//
//  Solid color design system (gradients deprecated)
//  Icon-inspired retro microphone aesthetic
//

import SwiftUI

// MARK: - Solid Color Backgrounds (Replacing Gradients)

extension View {
    /// Apply matte circle background for onboarding illustrations
    /// Image extends beyond circle for modern depth effect
    func matteCircleBackground(size: CGFloat = 120, color: Color) -> some View {
        self
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .background(
                Circle()
                    .fill(color.opacity(0.6))
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.3), radius: 15, x: 0, y: 5)
            )
    }

    /// Apply turquoise solid background (replaces voxxaPrimary gradient)
    func turquoiseSolidBackground() -> some View {
        self.background(Color.rsTurquoise)
    }

    /// Apply red solid background (replaces recording gradient)
    func redSolidBackground() -> some View {
        self.background(Color.rsRed)
    }

    /// Apply adaptive card background (charcoal/cream)
    func adaptiveCardBackground(for colorScheme: ColorScheme) -> some View {
        self.background(Color.rsCardBackground(for: colorScheme))
    }

    /// Apply charcoal background for dark mode cards
    func charcoalBackground() -> some View {
        self.background(Color.rsCharcoal)
    }

    /// Apply cream background for light mode elements
    func creamBackground() -> some View {
        self.background(Color.rsCream)
    }
}

// MARK: - Simple Background Gradient (Very Subtle Only)

extension LinearGradient {
    /// Very subtle background gradient (barely noticeable)
    static let subtleBackground = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.04, blue: 0.06),  // Very dark
            Color(red: 0.02, green: 0.02, blue: 0.04)   // Pure black
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Subtle glass overlay (for glassmorphism effects)
    static let glassOverlay = LinearGradient(
        colors: [
            Color.white.opacity(0.08),
            Color.white.opacity(0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Deprecated Gradient Functions (Use Solid Colors Instead)

extension LinearGradient {
    @available(*, deprecated, message: "Use Color.rsTurquoise solid background instead")
    static let voxxaPrimary = LinearGradient(
        colors: [Color.rsTurquoise, Color.rsTurquoise],
        startPoint: .leading,
        endPoint: .trailing
    )

    @available(*, deprecated, message: "Use Color.rsTurquoise solid background instead")
    static func voxxaPrimaryAdaptive(for colorScheme: ColorScheme) -> LinearGradient {
        return LinearGradient(
            colors: [Color.rsTurquoise, Color.rsTurquoise],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @available(*, deprecated, message: "Use Color.rsTurquoise solid background instead")
    static let voxxaPrimaryVertical = LinearGradient(
        colors: [Color.rsTurquoise, Color.rsTurquoise],
        startPoint: .top,
        endPoint: .bottom
    )

    @available(*, deprecated, message: "Use Color.rsRed solid background instead")
    static let voxxaSecondary = LinearGradient(
        colors: [Color.rsRed, Color.rsRed],
        startPoint: .leading,
        endPoint: .trailing
    )

    @available(*, deprecated, message: "Use Color.rsRed solid background instead")
    static let voxxaSecondaryVertical = LinearGradient(
        colors: [Color.rsRed, Color.rsRed],
        startPoint: .top,
        endPoint: .bottom
    )

    @available(*, deprecated, message: "Use Color.rsTurquoise solid background instead")
    static let voxxaIconCircle = LinearGradient(
        colors: [Color.rsTurquoise, Color.rsTurquoise],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    @available(*, deprecated, message: "Use Color.rsTurquoise solid background instead")
    static let voxxaMicrophone = LinearGradient(
        colors: [Color.rsTurquoise, Color.rsTurquoise],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    @available(*, deprecated, message: "Use Color.rsRed solid background instead")
    static let voxxaRecording = LinearGradient(
        colors: [Color.rsRed, Color.rsRed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    @available(*, deprecated, message: "Use LinearGradient.subtleBackground if needed")
    static let voxxaBackgroundSubtle = LinearGradient.subtleBackground

    @available(*, deprecated, message: "Use LinearGradient.glassOverlay if needed")
    static let voxxaGlassOverlay = LinearGradient.glassOverlay
}

// MARK: - Radial Gradients (Deprecated)

extension RadialGradient {
    @available(*, deprecated, message: "Use simple solid color shadows instead")
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

    @available(*, deprecated, message: "Use simple solid color shadows instead")
    static let voxxaIconGlow = RadialGradient(
        colors: [
            Color.rsTurquoise.opacity(0.3),
            Color.clear
        ],
        center: .center,
        startRadius: 20,
        endRadius: 120
    )
}

// MARK: - View Modifiers (Updated for Solid Colors)

extension View {
    /// Apply turquoise foreground color (replaces gradient foreground)
    func turquoiseForeground() -> some View {
        self.foregroundColor(.rsTurquoise)
    }

    /// Apply glow effect with turquoise color
    func turquoiseGlow() -> some View {
        self
            .shadow(color: Color.rsTurquoise.opacity(0.5), radius: 20, x: 0, y: 10)
            .shadow(color: Color.rsTurquoise.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    /// Apply glow effect with red color
    func redGlow() -> some View {
        self
            .shadow(color: Color.rsRed.opacity(0.5), radius: 20, x: 0, y: 10)
            .shadow(color: Color.rsRed.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    @available(*, deprecated, message: "Use turquoiseForeground() instead")
    func voxxaGradientForeground() -> some View {
        self.foregroundColor(.rsTurquoise)
    }

    @available(*, deprecated, message: "Use turquoiseGlow() or redGlow() instead")
    func voxxaGlow(color: Color = Color.rsTurquoise) -> some View {
        self
            .shadow(color: color.opacity(0.5), radius: 20, x: 0, y: 10)
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}
