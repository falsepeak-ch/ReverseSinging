//
//  DubCharacterStyle.swift
//  ReverseSinging
//
//  A colour per character, so who is speaking reads at a glance
//

import SwiftUI

/// Gives each character in a scene its own colour.
///
/// A dub screen shows one line at a time, and the caption alone does not say who is saying it.
/// A name helps; a name that is always the same colour helps more, because after two lines the
/// performer stops reading it and just recognises it.
enum DubCharacterStyle {

    /// Muted and close in luminance, so no character shouts louder than another and none of
    /// them competes with the record red. Deliberately not the app's semantic colours: amber
    /// already means "you have run long" on the record screen. By day each is taken deeper,
    /// so a name still reads on a white panel.
    static let palette: [Color] = [
        .rsDynamic(light: 0x3E6E98, dark: 0x6E9BC4),   // sky
        .rsDynamic(light: 0x8C6A1E, dark: 0xC9A45C),   // amber
        .rsDynamic(light: 0x4B7846, dark: 0x7FA87A),   // sage
        .rsDynamic(light: 0x62559A, dark: 0x9385BE),   // violet
        .rsDynamic(light: 0x9E4B5C, dark: 0xC97F8E),   // rose
        .rsDynamic(light: 0x2E726F, dark: 0x5FA3A0)    // teal
    ]

    /// The colour for `character` within a scene's cast.
    ///
    /// Keyed on position in the cast rather than a hash of the name, so the first speaker is
    /// always the first colour, stable across launches, and never two characters landing on
    /// the same hue in a scene small enough for it to matter.
    static func color(for character: String, in cast: [String]) -> Color {
        guard let index = cast.firstIndex(of: character) else { return .rsTextSecondary }
        return palette[index % palette.count]
    }
}

/// A character's name, in that character's colour.
///
/// The same plate wherever a line appears, over the picture, under the caption, in the line
/// list. So the association between a colour and a person is built once and then reused.
struct DubCharacterPlate: View {
    let character: String
    let color: Color

    /// Larger, for the one on the screen the performer is actually looking at.
    var isProminent: Bool = false

    var body: some View {
        HStack(spacing: isProminent ? 7 : 5) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(color)
                .frame(width: isProminent ? 3 : 2, height: isProminent ? 15 : 10)

            Text(character)
                .font(isProminent ? Font.system(size: 14, weight: .semibold) : .rsSectionLabel)
                .tracking(EditorMetrics.tracking)
                .textCase(.uppercase)
                .foregroundColor(color)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: Strings.Dub.speakerAccessibility, character)))
    }
}
