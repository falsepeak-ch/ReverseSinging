//
//  SpookyFigure.swift
//  ReverseSinging
//
//  One of the Spooky Voice Week clay characters, standing on its spot
//

import SwiftUI

/// A Spooky Voice Week clay character, cut out, in the style of the sound library's art.
enum SpookyCharacter: String {
    case pumpkin

    var imageName: String { "halloween-\(rawValue)" }

    /// The clear margin under the figure in its square artwork, as a share of its side. Taken
    /// off so it stands on its spot rather than hovering over it.
    var footMargin: CGFloat {
        switch self {
        case .pumpkin: 0.12
        }
    }
}

/// A character standing on a flat oval spot, the way a figurine stands on a shelf.
///
/// The spot is a step up the surface ramp, a little plinth, not a shadow: depth in this design
/// comes from the surface ramp, never from blur. With motion allowed the figure breathes, growing a touch from its feet and
/// settling again; with Reduce Motion on it stands still.
struct SpookyFigure: View {
    let character: SpookyCharacter
    let size: CGFloat
    /// Staggers the breathing so a group never moves as one block.
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    private var footY: CGFloat { size * (1 - character.footMargin) }
    private var spotHeight: CGFloat { size * 0.13 }

    var body: some View {
        // Top-aligned, so the feet land at `footY` and the spot is centred on them.
        ZStack(alignment: .top) {
            Ellipse()
                .fill(Color.rsSurface3)
                .overlay(Ellipse().strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline))
                .frame(width: size * 0.62, height: spotHeight)
                .offset(y: footY - spotHeight / 2)

            Image(character.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(
                    x: 1,
                    y: !reduceMotion && isBreathing ? 1.025 : 1,
                    anchor: UnitPoint(x: 0.5, y: 1 - character.footMargin)
                )
        }
        .frame(width: size, height: footY + spotHeight / 2, alignment: .top)
        .accessibilityHidden(true)
        .onAppear { breathe() }
        .onChange(of: reduceMotion) { _, _ in breathe() }
    }

    private func breathe() {
        guard !reduceMotion else {
            isBreathing = false
            return
        }
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true).delay(delay)) {
            isBreathing = true
        }
    }
}

#Preview {
    SpookyFigure(character: .pumpkin, size: 90)
        .padding()
        .background(Color.rsSurface2)
        .preferredColorScheme(.dark)
}
