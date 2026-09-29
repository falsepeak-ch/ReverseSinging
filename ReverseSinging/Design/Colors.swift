//
//  Colors.swift
//  ReverseSinging
//
//  Cinema-editor design system: a near-monochrome palette where colour only ever
//  means state, and the retro icon set supplies the personality. Every token has a
//  dark value (the edit suite at night) and a light one (the same desk by day).
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension Color {
    /// A token with a value for each appearance, resolved by whatever SwiftUI is drawing it in,
    /// so a screen held dark stays dark in a light app.
    ///
    /// Nonisolated, provider included: SwiftUI resolves colours on its render thread when the
    /// appearance changes, and a provider left on the main actor traps there.
    nonisolated static func rsDynamic(light: UInt32, dark: UInt32) -> Color {
        #if os(iOS)
        Color(UIColor { @Sendable traits in
            UIColor(rsHex: traits.userInterfaceStyle == .light ? light : dark)
        })
        #else
        Color(NSColor(name: nil) { @Sendable appearance in
            NSColor(rsHex: appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua ? light : dark)
        })
        #endif
    }
}

#if os(iOS)
private extension UIColor {
    nonisolated convenience init(rsHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#else
private extension NSColor {
    nonisolated convenience init(rsHex hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

extension Color {

    // MARK: - Surfaces
    //
    // A five-step neutral ramp, cool rather than pure grey. Panels are separated by
    // hairline strokes instead of drop shadows. That is what reads as a pro tool. In the
    // dark the canvas is the darkest step and panels lift towards the light; by day the
    // canvas is a soft grey and panels are paper, still told apart by the stroke.

    /// The app canvas. Nearly black so stills and waveforms carry the eye.
    static let rsSurface0 = rsDynamic(light: 0xECEEF1, dark: 0x0E0F11)

    /// Panels, cards, list rows.
    static let rsSurface1 = rsDynamic(light: 0xF8F9FA, dark: 0x16181B)

    /// Raised panels, popovers, the active row.
    static let rsSurface2 = rsDynamic(light: 0xFFFFFF, dark: 0x1E2125)

    /// Controls sitting on a panel, track fills, inactive segments.
    static let rsSurface3 = rsDynamic(light: 0xDFE2E7, dark: 0x282C31)

    /// Hairline borders. The single most important token in this design.
    static let rsStroke = rsDynamic(light: 0xD3D7DD, dark: 0x2E3237)

    /// Border for focused or selected elements.
    static let rsStrokeStrong = rsDynamic(light: 0xA9B0B8, dark: 0x454B52)

    // MARK: - Text

    static let rsTextPrimary = rsDynamic(light: 0x15181B, dark: 0xE8EAEC)
    static let rsTextSecondary = rsDynamic(light: 0x525961, dark: 0x9AA0A6)
    static let rsTextTertiary = rsDynamic(light: 0x7E858D, dark: 0x6B7278)

    // MARK: - State
    //
    // The only saturated colours in the interface. If something is coloured, it is
    // telling you what the app is doing.

    // By day each is a shade deeper, so it holds its contrast on a light panel.

    /// Armed / recording. Never used for decoration.
    static let rsRecord = rsDynamic(light: 0xD5383E, dark: 0xE5484D)

    /// A take is captured, a step is complete.
    static let rsGood = rsDynamic(light: 0x2B8A4B, dark: 0x3DA35D)

    /// Over length, needs attention.
    static let rsCaution = rsDynamic(light: 0xA7791D, dark: 0xC79A3A)

    /// Reserved highlight, playheads, active scrub, selected tab underline.
    /// Deliberately desaturated so it never competes with the state colours.
    static let rsHighlight = rsDynamic(light: 0x4C6A78, dark: 0x7A929D)

    // MARK: - Aliases
    //
    // Kept so the screens built around the old icon-set palette resolve to the editor
    // colours without every call site being rewritten.

    /// Alias so the screens that were built around "the accent" pick up the editor
    /// highlight instead of the old teal, without each call site being rewritten.
    static let rsTurquoise = rsHighlight

    /// Red from the icon set. For interface state prefer `rsRecord`.
    static let rsRed = rsRecord

    // MARK: - Backgrounds
    //
    // The tokens adapt by themselves, so the "adaptive" helpers ignore the colour scheme
    // they are handed. They are kept so every existing call site resolves to the editor
    // palette without being rewritten.

    static let rsBackground = rsSurface0

    static func rsBackgroundAdaptive(for colorScheme: ColorScheme) -> Color { rsSurface0 }

    static func rsSecondaryBackgroundAdaptive(for colorScheme: ColorScheme) -> Color { rsSurface1 }

    // MARK: - Cards

    static func rsCardBackground(for colorScheme: ColorScheme) -> Color { rsSurface1 }

    // MARK: - Text Helpers

    static func rsTextAdaptive(for colorScheme: ColorScheme) -> Color { rsTextPrimary }

    static func rsSecondaryTextAdaptive(for colorScheme: ColorScheme) -> Color { rsTextSecondary }

    static let rsSecondaryText = rsTextSecondary

    /// On a highlight fill: near-white in the dark, pure white by day, where the fill is deeper.
    static let rsTextOnTurquoise = rsDynamic(light: 0xFFFFFF, dark: 0xE8EAEC)
    static let rsTextOnRed = Color.white

    // MARK: - Semantic

    static let rsSuccess = rsGood
    static let rsWarning = rsCaution

    // MARK: - Audio State

    static let rsRecording = rsRecord

    // MARK: - Buttons
    //
    // Primary is a light key on a dark field. The one bright element on screen, so
    // there is never any doubt what the main action is.

    static func rsButtonPrimaryAdaptive(for colorScheme: ColorScheme) -> Color { rsTextPrimary }

    static func rsTextOnPrimaryButton(for colorScheme: ColorScheme) -> Color { rsSurface0 }

    static func rsButtonSecondaryAdaptive(for colorScheme: ColorScheme) -> Color { rsSurface2 }

    static let rsButtonDisabled = rsSurface2.opacity(0.5)
    static let rsButtonDestructive = rsRecord

    // MARK: - Waveform

    static func rsWaveformRecordingAdaptive(for colorScheme: ColorScheme) -> Color { rsRecord }

    static func rsWaveformPlayingAdaptive(for colorScheme: ColorScheme) -> Color { rsHighlight }

    static func rsWaveformIdleAdaptive(for colorScheme: ColorScheme) -> Color { rsSurface3 }

    static let rsWaveformInactive = rsSurface3
    static let rsWaveformRecording = rsRecord
    static let rsWaveformPlaying = rsHighlight
}
