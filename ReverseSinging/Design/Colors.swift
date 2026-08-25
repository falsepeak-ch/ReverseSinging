//
//  Colors.swift
//  ReverseSinging
//
//  Cinema-editor design system: a near-monochrome dark palette where colour
//  only ever means state, and the retro icon set supplies the personality.
//

import SwiftUI

extension Color {

    // MARK: - Surfaces
    //
    // A five-step neutral ramp, cool rather than pure grey. Panels are separated by
    // hairline strokes instead of drop shadows — that is what reads as a pro tool.

    /// The app canvas. Nearly black so stills and waveforms carry the eye.
    static let rsSurface0 = Color(red: 0.055, green: 0.059, blue: 0.067)   // #0E0F11

    /// Panels, cards, list rows.
    static let rsSurface1 = Color(red: 0.086, green: 0.094, blue: 0.106)   // #16181B

    /// Raised panels, popovers, the active row.
    static let rsSurface2 = Color(red: 0.118, green: 0.129, blue: 0.145)   // #1E2125

    /// Controls sitting on a panel — track fills, inactive segments.
    static let rsSurface3 = Color(red: 0.157, green: 0.173, blue: 0.192)   // #282C31

    /// Hairline borders. The single most important token in this design.
    static let rsStroke = Color(red: 0.180, green: 0.196, blue: 0.216)     // #2E3237

    /// Border for focused or selected elements.
    static let rsStrokeStrong = Color(red: 0.271, green: 0.294, blue: 0.322)  // #454B52

    // MARK: - Text

    static let rsTextPrimary = Color(red: 0.910, green: 0.918, blue: 0.925)   // #E8EAEC
    static let rsTextSecondary = Color(red: 0.604, green: 0.627, blue: 0.651) // #9AA0A6
    static let rsTextTertiary = Color(red: 0.420, green: 0.447, blue: 0.471)  // #6B7278

    // MARK: - State
    //
    // The only saturated colours in the interface. If something is coloured, it is
    // telling you what the app is doing.

    /// Armed / recording. Never used for decoration.
    static let rsRecord = Color(red: 0.898, green: 0.282, blue: 0.302)     // #E5484D

    /// A take is captured, a step is complete.
    static let rsGood = Color(red: 0.239, green: 0.639, blue: 0.365)       // #3DA35D

    /// Over length, needs attention.
    static let rsCaution = Color(red: 0.780, green: 0.604, blue: 0.227)    // #C79A3A

    /// Reserved highlight — playheads, active scrub, selected tab underline.
    /// Deliberately desaturated so it never competes with the state colours.
    static let rsHighlight = Color(red: 0.478, green: 0.573, blue: 0.616)  // #7A929D

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
    // The interface is dark-only, so the "adaptive" helpers ignore the colour scheme.
    // They are kept so every existing call site resolves to the editor palette without
    // being rewritten.

    static let rsBackground = rsSurface0

    static func rsBackgroundAdaptive(for colorScheme: ColorScheme) -> Color { rsSurface0 }

    static func rsSecondaryBackgroundAdaptive(for colorScheme: ColorScheme) -> Color { rsSurface1 }

    // MARK: - Cards

    static func rsCardBackground(for colorScheme: ColorScheme) -> Color { rsSurface1 }

    // MARK: - Text Helpers

    static func rsTextAdaptive(for colorScheme: ColorScheme) -> Color { rsTextPrimary }

    static func rsSecondaryTextAdaptive(for colorScheme: ColorScheme) -> Color { rsTextSecondary }

    static let rsSecondaryText = rsTextSecondary

    static let rsTextOnTurquoise = rsTextPrimary
    static let rsTextOnRed = Color.white

    // MARK: - Semantic

    static let rsSuccess = rsGood
    static let rsWarning = rsCaution

    // MARK: - Audio State

    static let rsRecording = rsRecord

    // MARK: - Buttons
    //
    // Primary is a light key on a dark field — the one bright element on screen, so
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
