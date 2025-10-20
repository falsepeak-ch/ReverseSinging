//
//  Colors.swift
//  ReverseSinging
//
//  Design system color palette
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let rsAccent = Color("AccentColor", bundle: nil)
    static let rsPrimary = Color(red: 0.2, green: 0.6, blue: 1.0)      // Vibrant blue
    static let rsSecondary = Color(red: 0.4, green: 0.3, blue: 0.9)    // Purple

    // MARK: - Background Colors
    static let rsBackground = Color(uiColor: .systemBackground)
    static let rsSecondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let rsTertiaryBackground = Color(uiColor: .tertiarySystemBackground)

    // MARK: - Text Colors
    static let rsText = Color(uiColor: .label)
    static let rsSecondaryText = Color(uiColor: .secondaryLabel)
    static let rsTertiaryText = Color(uiColor: .tertiaryLabel)

    // MARK: - Semantic Colors
    static let rsSuccess = Color.green
    static let rsError = Color.red
    static let rsWarning = Color.orange

    // MARK: - Audio State Colors
    static let rsRecording = Color.red
    static let rsPlaying = Color.green
    static let rsReversed = Color.purple
    static let rsWaveform = Color.blue.opacity(0.6)

    // MARK: - Button Colors
    static let rsButtonBackground = Color.blue
    static let rsButtonText = Color.white
    static let rsButtonDisabled = Color.gray.opacity(0.3)

    // MARK: - Gradient
    static let rsPrimaryGradient = LinearGradient(
        colors: [Color.rsPrimary, Color.rsSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
