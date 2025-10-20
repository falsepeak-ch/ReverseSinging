//
//  Colors.swift
//  ReverseSinging
//
//  Premium design system color palette
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors (Yellow/Gold Theme)
    static let rsGold = Color(red: 0.957, green: 0.773, blue: 0.259)           // #F4C542 - Warm gold
    static let rsGoldLight = Color(red: 0.988, green: 0.867, blue: 0.467)      // Lighter gold
    static let rsGoldDark = Color(red: 0.867, green: 0.655, blue: 0.129)       // Darker gold

    // MARK: - Background Colors
    static let rsBackground = Color(uiColor: .systemBackground)
    static let rsSecondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let rsTertiaryBackground = Color(uiColor: .tertiarySystemBackground)

    // Card backgrounds
    static let rsCardBackground = Color(uiColor: .secondarySystemBackground)
    static let rsElevatedCard = Color(uiColor: .tertiarySystemBackground)

    // MARK: - Text Colors
    static let rsText = Color(uiColor: .label)
    static let rsSecondaryText = Color(uiColor: .secondaryLabel)
    static let rsTertiaryText = Color(uiColor: .tertiaryLabel)
    static let rsTextOnGold = Color(red: 0.2, green: 0.15, blue: 0.0)          // Dark text on gold

    // MARK: - Semantic Colors
    static let rsSuccess = Color.green
    static let rsError = Color(red: 0.95, green: 0.27, blue: 0.27)             // Softer red
    static let rsWarning = Color.orange

    // MARK: - Audio State Colors
    static let rsRecording = Color(red: 0.95, green: 0.27, blue: 0.27)         // Elegant red
    static let rsPlaying = Color(red: 0.2, green: 0.7, blue: 0.9)              // Soft blue
    static let rsReversed = Color(red: 0.6, green: 0.4, blue: 0.9)             // Soft purple
    static let rsProcessing = Color.rsGold

    // Waveform colors
    static let rsWaveformActive = Color.white.opacity(0.9)
    static let rsWaveformInactive = Color.gray.opacity(0.3)
    static let rsWaveformRecording = Color(red: 0.95, green: 0.27, blue: 0.27)
    static let rsWaveformPlaying = Color(red: 0.2, green: 0.7, blue: 0.9)

    // MARK: - Button Colors
    static let rsButtonPrimary = Color.rsGold
    static let rsButtonSecondary = Color(uiColor: .tertiarySystemBackground)
    static let rsButtonDisabled = Color.gray.opacity(0.3)
    static let rsButtonDestructive = Color(red: 0.95, green: 0.27, blue: 0.27)

    // MARK: - Gradients
    static let rsGoldGradient = LinearGradient(
        colors: [Color.rsGoldLight, Color.rsGold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let rsWaveformGradient = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.4)],
        startPoint: .bottom,
        endPoint: .top
    )
}
