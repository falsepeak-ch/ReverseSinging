//
//  Colors.swift
//  ReverseSinging
//
//  Voxxa-inspired dark gradient design system
//

import SwiftUI

extension Color {
    // MARK: - Background Colors (Dark Theme)

    /// Deep black background (like Voxxa)
    static let rsBackground = Color(red: 0.04, green: 0.04, blue: 0.04)  // #0A0A0A
    static let rsSecondaryBackground = Color(red: 0.1, green: 0.1, blue: 0.12)  // Slightly lighter
    static let rsTertiaryBackground = Color(red: 0.15, green: 0.15, blue: 0.18)  // Even lighter

    // MARK: - Gradient Colors

    /// Cyan (primary gradient start)
    static let rsGradientCyan = Color(red: 0.0, green: 0.85, blue: 1.0)  // #00D9FF

    /// Purple (primary gradient end)
    static let rsGradientPurple = Color(red: 0.66, green: 0.33, blue: 0.97)  // #A855F7

    /// Blue (secondary gradient)
    static let rsGradientBlue = Color(red: 0.23, green: 0.51, blue: 0.96)  // #3B82F6

    /// Pink (secondary gradient)
    static let rsGradientPink = Color(red: 0.93, green: 0.28, blue: 0.60)  // #EC4899

    // MARK: - Card/Glass Backgrounds

    /// Glassmorphic card background
    static let rsCardBackground = Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.6)

    /// Elevated glassmorphic card
    static let rsElevatedCard = Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.7)

    /// Dark card (less transparent)
    static let rsDarkCard = Color(red: 0.12, green: 0.12, blue: 0.14)

    // MARK: - Text Colors

    /// Primary text (white)
    static let rsText = Color.white

    /// Secondary text (gray)
    static let rsSecondaryText = Color(red: 0.6, green: 0.6, blue: 0.65)

    /// Tertiary text (darker gray)
    static let rsTertiaryText = Color(red: 0.4, green: 0.4, blue: 0.45)

    /// Text on gradient backgrounds
    static let rsTextOnGradient = Color.white

    /// Text on gold/gradient backgrounds (legacy compat)
    static let rsTextOnGold = Color.white

    // MARK: - Legacy/Compatibility (for gradual migration)

    /// Legacy gold (deprecated - use gradients instead)
    @available(*, deprecated, message: "Use LinearGradient.voxxaPrimary instead")
    static let rsGold = Color(red: 0.66, green: 0.33, blue: 0.97)  // Purple for now

    @available(*, deprecated, message: "Use LinearGradient.voxxaPrimary instead")
    static let rsGoldLight = Color(red: 0.0, green: 0.85, blue: 1.0)  // Cyan

    @available(*, deprecated, message: "Use LinearGradient.voxxaPrimary instead")
    static let rsGoldDark = Color(red: 0.66, green: 0.33, blue: 0.97)  // Purple

    // MARK: - Semantic Colors

    static let rsSuccess = Color(red: 0.2, green: 0.85, blue: 0.5)  // Bright green
    static let rsError = Color(red: 0.95, green: 0.27, blue: 0.50)  // Pink-red
    static let rsWarning = Color(red: 1.0, green: 0.7, blue: 0.0)  // Amber

    // MARK: - Audio State Colors

    /// Recording state (gradient pink)
    static let rsRecording = Color.rsGradientPink

    /// Playing state (gradient cyan)
    static let rsPlaying = Color.rsGradientCyan

    /// Reversed state (gradient purple)
    static let rsReversed = Color.rsGradientPurple

    /// Processing state (gradient blue)
    static let rsProcessing = Color.rsGradientBlue

    // MARK: - Waveform Colors

    static let rsWaveformActive = Color.white.opacity(0.9)
    static let rsWaveformInactive = Color.gray.opacity(0.2)
    static let rsWaveformRecording = Color.rsGradientPink
    static let rsWaveformPlaying = Color.rsGradientCyan

    // MARK: - Button Colors

    /// Button colors are now gradients - see GradientStyles.swift
    static let rsButtonPrimary = Color.rsGradientCyan  // Fallback
    static let rsButtonSecondary = Color.rsSecondaryBackground
    static let rsButtonDisabled = Color.gray.opacity(0.2)
    static let rsButtonDestructive = Color.rsError

    // MARK: - Legacy Gradients (use GradientStyles.swift instead)

    /// Use LinearGradient.voxxaPrimary instead
    @available(*, deprecated, message: "Use LinearGradient.voxxaPrimary instead")
    static let rsGoldGradient = LinearGradient(
        colors: [Color.rsGradientCyan, Color.rsGradientPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    @available(*, deprecated, message: "Use LinearGradient.voxxaGlassOverlay instead")
    static let rsWaveformGradient = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.4)],
        startPoint: .bottom,
        endPoint: .top
    )
}
