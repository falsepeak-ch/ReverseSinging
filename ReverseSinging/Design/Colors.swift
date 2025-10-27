//
//  Colors.swift
//  ReverseSinging
//
//  Retro microphone icon-inspired design system
//  Solid colors with excellent light/dark mode contrast
//

import SwiftUI

extension Color {
    // MARK: - Primary Palette (from icon)

    /// Turquoise - Primary accent color (from icon background)
    static let rsTurquoise = Color(red: 0.176, green: 0.847, blue: 0.839)  // #2DD8D6

    /// Red/Coral - Recording and destructive actions (from icon button)
    static let rsRed = Color(red: 1.0, green: 0.333, blue: 0.333)  // #FF5555

    /// Cream/Beige - Secondary accent (from icon microphone body)
    static let rsCream = Color(red: 0.961, green: 0.945, blue: 0.894)  // #F5F1E4

    /// Charcoal - Dark cards and secondary backgrounds (from icon elements)
    static let rsCharcoal = Color(red: 0.176, green: 0.275, blue: 0.329)  // #2D4654

    // MARK: - Background Colors

    /// Deep black background (dark mode)
    static let rsBackground = Color(red: 0.04, green: 0.04, blue: 0.04)  // #0A0A0A

    /// Light background (light mode)
    static let rsBackgroundLight = Color(red: 0.98, green: 0.98, blue: 0.98)  // #FAFAFA

    /// Secondary background (dark mode - slightly lighter)
    static let rsSecondaryBackground = Color(red: 0.1, green: 0.1, blue: 0.12)  // #19191E

    /// Secondary background (light mode)
    static let rsSecondaryBackgroundLight = Color(red: 0.95, green: 0.95, blue: 0.95)  // #F2F2F2

    /// Tertiary background (dark mode)
    static let rsTertiaryBackground = Color(red: 0.15, green: 0.15, blue: 0.18)  // #26262E

    // MARK: - Adaptive Backgrounds (for hybrid approach)

    /// Adaptive primary background
    static func rsBackgroundAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? rsBackground : rsBackgroundLight
    }

    /// Adaptive secondary background
    static func rsSecondaryBackgroundAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? rsSecondaryBackground : rsSecondaryBackgroundLight
    }

    // MARK: - Card Backgrounds (hybrid approach)

    /// Card background - charcoal in dark mode, cream in light mode
    static func rsCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? rsCharcoal.opacity(0.85)
            : rsCream.opacity(0.9)
    }

    /// Elevated card - darker charcoal in dark mode, white in light mode
    static func rsElevatedCard(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? rsCharcoal
            : Color.white
    }

    /// Glass card (semi-transparent)
    static func rsGlassCard(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.7)
            : Color.white.opacity(0.7)
    }

    // MARK: - Legacy Card Colors (for backward compatibility)

    static let rsCardBackground = Color.rsCharcoal.opacity(0.85)
    static let rsElevatedCard = Color.rsCharcoal
    static let rsDarkCard = Color.rsCharcoal

    // MARK: - Text Colors

    /// Primary text - white in dark mode, charcoal in light mode
    static func rsTextAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : rsCharcoal
    }

    /// Secondary text
    static func rsSecondaryTextAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.6, green: 0.6, blue: 0.65)
            : Color(red: 0.4, green: 0.4, blue: 0.45)
    }

    /// Tertiary text
    static func rsTertiaryTextAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.45)
            : Color(red: 0.6, green: 0.6, blue: 0.65)
    }

    /// Legacy text colors (non-adaptive)
    static let rsText = Color.white
    static let rsSecondaryText = Color(red: 0.6, green: 0.6, blue: 0.65)
    static let rsTertiaryText = Color(red: 0.4, green: 0.4, blue: 0.45)

    /// Text on turquoise backgrounds (always white for contrast)
    static let rsTextOnTurquoise = Color.white

    /// Text on red backgrounds (always white for contrast)
    static let rsTextOnRed = Color.white

    /// Text on cream backgrounds (always charcoal for contrast)
    static let rsTextOnCream = Color.rsCharcoal

    // MARK: - Semantic Colors

    static let rsSuccess = Color(red: 0.2, green: 0.85, blue: 0.5)  // Bright green
    static let rsError = rsRed  // Use icon red
    static let rsWarning = Color(red: 1.0, green: 0.7, blue: 0.0)  // Amber

    // MARK: - Audio State Colors

    /// Recording state - red from icon
    static let rsRecording = rsRed

    /// Playing state - turquoise from icon
    static let rsPlaying = rsTurquoise

    /// Reversed state - turquoise variant (slightly darker)
    static let rsReversed = Color(red: 0.1, green: 0.7, blue: 0.7)  // Darker turquoise

    /// Processing state - turquoise with animation
    static let rsProcessing = rsTurquoise

    // MARK: - Button Colors

    /// Primary button - turquoise
    static let rsButtonPrimary = rsTurquoise

    /// Secondary button - charcoal in dark, cream in light
    static func rsButtonSecondaryAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? rsCharcoal : rsCream
    }

    static let rsButtonSecondary = rsCharcoal
    static let rsButtonDisabled = Color.gray.opacity(0.2)
    static let rsButtonDestructive = rsRed

    // MARK: - Waveform Colors (Adaptive with Strong Contrast)

    /// Recording waveform - red in both modes (darker in light mode)
    static func rsWaveformRecordingAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.4, blue: 0.4)      // Bright red in dark mode
            : Color(red: 0.85, green: 0.15, blue: 0.15)   // Darker red in light mode
    }

    /// Playing waveform - turquoise in both modes (darker in light mode)
    static func rsWaveformPlayingAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? rsTurquoise                                  // Bright turquoise in dark mode
            : Color(red: 0.1, green: 0.65, blue: 0.65)    // Darker turquoise in light mode
    }

    /// Idle waveform - white/gray depending on mode
    static func rsWaveformIdleAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.5)                     // White in dark mode
            : Color.gray.opacity(0.6)                      // Gray in light mode
    }

    /// Legacy waveform colors (dark mode defaults)
    static let rsWaveformActive = Color.white.opacity(0.9)
    static let rsWaveformInactive = Color.gray.opacity(0.2)
    static let rsWaveformRecording = rsRed
    static let rsWaveformPlaying = rsTurquoise

    // MARK: - Legacy/Deprecated Colors (for gradual migration)

    @available(*, deprecated, message: "Use rsTurquoise instead")
    static let rsGold = rsTurquoise

    @available(*, deprecated, message: "Use rsTurquoise instead")
    static let rsGoldLight = rsTurquoise

    @available(*, deprecated, message: "Use rsTurquoise instead")
    static let rsGoldDark = rsTurquoise

    @available(*, deprecated, message: "Use rsTurquoise instead")
    static let rsGradientCyan = rsTurquoise

    @available(*, deprecated, message: "Use rsRed instead")
    static let rsGradientPink = rsRed

    @available(*, deprecated, message: "Use rsTurquoise instead")
    static let rsGradientBlue = rsTurquoise

    @available(*, deprecated, message: "Use rsCharcoal instead")
    static let rsGradientPurple = rsCharcoal

    @available(*, deprecated, message: "Use rsTextOnTurquoise instead")
    static let rsTextOnGradient = Color.white

    @available(*, deprecated, message: "Use rsTextOnTurquoise instead")
    static let rsTextOnGold = Color.white
}
