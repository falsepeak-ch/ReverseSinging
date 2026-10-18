//
//  Typography.swift
//  ReverseSinging
//
//  Premium typography system
//

import SwiftUI

extension Font {
    /// The studio's type is the system's default design; in the game, the rounded one, so the
    /// shared screens match the game's own running text.
    #if DUBLOON_GAME
    static let rsTextDesign: Font.Design = .rounded
    #else
    static let rsTextDesign: Font.Design = .default
    #endif


    // MARK: - Display
    //
    // Eugello is the logo's face and nothing else's. It is drawn into the `icon-lettering`
    // image on the home header rather than set in any `Text`, so titles, headings and the
    // score all use the system font, and the wordmark is the only serif lettering on screen.
    //
    // The named sizes sit on text styles so they scale with Dynamic Type.

    /// Display type at an arbitrary size, for the two places that compute one.
    ///
    /// Prefer the named sizes below. This exists because the onboarding title scales itself to
    /// the screen height and the score card sets its own size.
    static func rsDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: rsTextDesign)
    }

    /// Onboarding and first-run titles: the largest type in the app.
    static let rsDisplayLarge = Font.system(.largeTitle, design: rsTextDesign, weight: .bold)

    /// Section titles that carry a screen on their own.
    static let rsDisplayMedium = Font.system(.title, design: rsTextDesign, weight: .bold)

    // MARK: - Timer Display (Monospaced)
    // Note: Use .monospaced() view modifier for full monospace including punctuation
    //
    // These are digits that change every frame and need tabular figures to stop jittering.
    static let rsTimerLarge = Font.system(size: 72, weight: .medium, design: rsTextDesign)

    // MARK: - Headings
    //
    // `rsHeadingSmall` is what `EditorScreenHeader` uses, so it is the title on every pushed
    // screen in the app.
    static let rsHeadingMedium = Font.system(.title2, design: rsTextDesign, weight: .semibold)
    static let rsHeadingSmall = Font.system(.title3, design: rsTextDesign, weight: .semibold)

    // MARK: - Body
    static let rsBodyLarge = Font.system(size: 18, weight: .regular, design: rsTextDesign)
    static let rsBodyMedium = Font.system(size: 16, weight: .regular, design: rsTextDesign)
    static let rsBodySmall = Font.system(size: 14, weight: .regular, design: rsTextDesign)

    // MARK: - Button
    static let rsButtonLarge = Font.system(size: 18, weight: .semibold, design: rsTextDesign)
    static let rsButtonMedium = Font.system(size: 16, weight: .semibold, design: rsTextDesign)
    static let rsButtonSmall = Font.system(size: 14, weight: .medium, design: rsTextDesign)

    // MARK: - Caption
    static let rsCaption = Font.system(size: 13, weight: .medium, design: rsTextDesign)
    static let rsCaptionSmall = Font.system(size: 11, weight: .medium, design: rsTextDesign)

    // MARK: - Label (for metadata)
    static let rsLabelSmall = Font.system(size: 10, weight: .regular, design: rsTextDesign)

    // MARK: - Editor Typography
    //
    // Every number that changes over time is monospaced, so timecodes and counters
    // stop jittering as digits change. The detail that most makes a UI read as a tool.

    static let rsTimecodeLarge = Font.system(size: 44, weight: .medium, design: .monospaced)
    static let rsTimecode = Font.system(size: 15, weight: .medium, design: .monospaced)
    static let rsTimecodeSmall = Font.system(size: 12, weight: .medium, design: .monospaced)

    /// Panel and section headers. Always paired with `.rsTracking` and uppercased.
    static let rsSectionLabel = Font.system(size: 11, weight: .semibold, design: rsTextDesign)

    /// Metadata inside dense rows.
    static let rsMeta = Font.system(size: 12, weight: .medium, design: rsTextDesign)
}
