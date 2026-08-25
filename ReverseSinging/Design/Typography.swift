//
//  Typography.swift
//  ReverseSinging
//
//  Premium typography system
//

import SwiftUI

extension Font {
    // MARK: - Timer Display (Monospaced)
    // Note: Use .monospaced() view modifier for full monospace including punctuation
    static let rsTimerLarge = Font.system(size: 72, weight: .medium, design: .default)

    // MARK: - Headings
    static let rsHeadingMedium = Font.system(size: 24, weight: .semibold, design: .default)
    static let rsHeadingSmall = Font.system(size: 20, weight: .semibold, design: .default)

    // MARK: - Body
    static let rsBodyLarge = Font.system(size: 18, weight: .regular, design: .default)
    static let rsBodyMedium = Font.system(size: 16, weight: .regular, design: .default)
    static let rsBodySmall = Font.system(size: 14, weight: .regular, design: .default)

    // MARK: - Button
    static let rsButtonLarge = Font.system(size: 18, weight: .semibold, design: .default)
    static let rsButtonMedium = Font.system(size: 16, weight: .semibold, design: .default)
    static let rsButtonSmall = Font.system(size: 14, weight: .medium, design: .default)

    // MARK: - Caption
    static let rsCaption = Font.system(size: 13, weight: .medium, design: .default)
    static let rsCaptionSmall = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - Label (for metadata)
    static let rsLabelSmall = Font.system(size: 10, weight: .regular, design: .default)

    // MARK: - Editor Typography
    //
    // Every number that changes over time is monospaced, so timecodes and counters
    // stop jittering as digits change — the detail that most makes a UI read as a tool.

    static let rsTimecodeLarge = Font.system(size: 44, weight: .medium, design: .monospaced)
    static let rsTimecode = Font.system(size: 15, weight: .medium, design: .monospaced)
    static let rsTimecodeSmall = Font.system(size: 12, weight: .medium, design: .monospaced)

    /// Panel and section headers. Always paired with `.rsTracking` and uppercased.
    static let rsSectionLabel = Font.system(size: 11, weight: .semibold, design: .default)

    /// Metadata inside dense rows.
    static let rsMeta = Font.system(size: 12, weight: .medium, design: .default)
}
