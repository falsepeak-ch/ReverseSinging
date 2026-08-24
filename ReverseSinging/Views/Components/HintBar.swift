//
//  HintBar.swift
//  ReverseSinging
//
//  The bottom status strip: what to do next, in one line.
//

import SwiftUI

/// A status strip pinned to the bottom edge, the way an editor reports the next step.
///
/// Only the *background* runs into the home-indicator area. Letting the whole strip
/// ignore the safe area — as both main views used to — pushed the text under the
/// indicator, where it was clipped and unreadable. The label is fixed-size and the
/// hint wraps instead of truncating, so a long or translated tip still reads in full.
struct HintBar: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            EditorRule()

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Strings.Main.Section.hint)
                    .editorLabelStyle(.rsHighlight)
                    .fixedSize()

                Text(text)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.vertical, 12)
        }
        .background(Color.rsSurface1.ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        VStack {
            Spacer()
            HintBar(text: "Listen to reversed audio, then record")
        }
    }
}
