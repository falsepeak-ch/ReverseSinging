//
//  Typography.swift
//  ReverseSinging
//
//  Premium typography system
//

import SwiftUI

extension Font {

    // MARK: - Display Face
    //
    // Eugello is the app's own face and it is used for titles only: screen headers, page
    // titles, the score. Everything a user reads *at length* stays on the system font, which
    // is what SF is good at and what a display serif is not.
    //
    // Three things constrain how it can be used, all of them properties of the file itself:
    //
    // * **It has one weight.** There is no Eugello Bold, so nothing here asks for a weight and
    //   no call site should add `.bold()`. A synthesised bold on a serif this heavy smears the
    //   joins. The face already reads heavier than SF at the same size, which is the effect
    //   those `.semibold` headings wanted in the first place.
    // * **It covers Latin only.** All six Latin locales are complete, accents included; there
    //   is no CJK. Japanese titles fall back to the system font whole, which is the right
    //   outcome. A title is one string, so it substitutes cleanly rather than mid-word.
    // * **It has no ellipsis glyph.** A `…` inside a title would fall back on that one
    //   character and sit visibly wrong between two serif letters. Today every string
    //   containing one is a progress message on `rsTimecodeSmall` or a label, none of them
    //   titles. Keep it that way, or spell it "..." if a title ever needs one.
    //
    // Sized `relativeTo:` so titles scale with Dynamic Type. `Font.custom(_:size:)` without it
    // is fixed, which is why the four hand-rolled call sites this replaces ignored the user's
    // text-size setting entirely.

    private static let displayFace = "Eugello"

    /// The display face at an arbitrary size, for the two places that compute one.
    ///
    /// Prefer the named sizes below. This exists because the onboarding title scales itself to
    /// the screen height and the score card sets its own size.
    static func rsDisplay(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(displayFace, size: size, relativeTo: style)
    }

    /// Onboarding and first-run titles: the largest type in the app.
    static let rsDisplayLarge = Font.custom(displayFace, size: 36, relativeTo: .largeTitle)

    /// Section titles that carry a screen on their own.
    static let rsDisplayMedium = Font.custom(displayFace, size: 28, relativeTo: .title)

    // MARK: - Timer Display (Monospaced)
    // Note: Use .monospaced() view modifier for full monospace including punctuation
    //
    // Stays on the system font deliberately: these are digits that change every frame and need
    // tabular figures to stop jittering. A proportional serif is the wrong tool.
    static let rsTimerLarge = Font.system(size: 72, weight: .medium, design: .default)

    // MARK: - Headings
    //
    // The display face. `rsHeadingSmall` is what `EditorScreenHeader` uses, so this is the line
    // that puts Eugello on the title bar of every screen in the app.
    static let rsHeadingMedium = Font.custom(displayFace, size: 24, relativeTo: .title2)
    static let rsHeadingSmall = Font.custom(displayFace, size: 20, relativeTo: .title3)

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
    // stop jittering as digits change. The detail that most makes a UI read as a tool.

    static let rsTimecodeLarge = Font.system(size: 44, weight: .medium, design: .monospaced)
    static let rsTimecode = Font.system(size: 15, weight: .medium, design: .monospaced)
    static let rsTimecodeSmall = Font.system(size: 12, weight: .medium, design: .monospaced)

    /// Panel and section headers. Always paired with `.rsTracking` and uppercased.
    static let rsSectionLabel = Font.system(size: 11, weight: .semibold, design: .default)

    /// Metadata inside dense rows.
    static let rsMeta = Font.system(size: 12, weight: .medium, design: .default)
}
