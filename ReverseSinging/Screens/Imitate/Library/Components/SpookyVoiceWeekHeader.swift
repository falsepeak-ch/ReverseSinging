//
//  SpookyVoiceWeekHeader.swift
//  ReverseSinging
//
//  The Halloween line over the sound library, shown only during Spooky Voice Week
//

import SwiftUI

/// The dates, the name of the week, and the sounds in the library that suit it, with the
/// pumpkin sitting on the panel's top edge. Decoration, not a control: the sounds it names are
/// in the grid below, where they always are.
///
/// The pumpkin stands on the edge itself, its spot centred on the hairline, and takes no room
/// in the panel. The caller leaves `headroom` above the panel for it.
struct SpookyVoiceWeekHeader: View {

    private static let pumpkinSize: CGFloat = 72

    /// The pumpkin's height above the edge it stands on, less the clear margin over its stem.
    static let headroom: CGFloat = pumpkinSize * 0.76

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(SpookyVoiceWeek.dateRangeText())
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsRecord)

            Text(Strings.Halloween.title)
                .font(.rsButtonMedium)
                .foregroundColor(.rsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(Strings.Halloween.imitateMessage)
                .font(.rsMeta)
                .foregroundColor(.rsTextSecondary)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(.rsSurface1, stroke: Color.rsRecord.opacity(0.35))
        .overlay(alignment: .topTrailing) {
            SpookyFigure(character: .pumpkin, size: Self.pumpkinSize)
                // The feet, and the middle of the spot, on the top hairline.
                .alignmentGuide(.top) { d in d.height - Self.pumpkinSize * 0.065 }
                .padding(.trailing, 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Strings.Halloween.title), \(SpookyVoiceWeek.dateRangeText()). \(Strings.Halloween.imitateMessage)")
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        SpookyVoiceWeekHeader()
            .padding(.top, SpookyVoiceWeekHeader.headroom)
            .padding(EditorMetrics.gutter)
    }
    .preferredColorScheme(.dark)
}
