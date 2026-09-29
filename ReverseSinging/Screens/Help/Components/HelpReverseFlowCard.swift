//
//  HelpReverseFlowCard.swift
//  ReverseSinging
//
//  Reverse singing in four pictures: the idea people most often miss, drawn rather than told
//

import SwiftUI

/// Sing, flip, copy, flip back: four waveforms in a row, lit one after another, so the loop
/// that turns a backwards copy back into the song can be watched rather than read.
///
/// The first and last waveforms are the same shape on purpose. That is the whole trick.
struct HelpReverseFlowCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step: Int, CaseIterable {
        case sing, flip, copy, flipBack

        var title: String {
            switch self {
            case .sing: Strings.Help.Flow.sing
            case .flip: Strings.Help.Flow.flip
            case .copy: Strings.Help.Flow.copy
            case .flipBack: Strings.Help.Flow.flipBack
            }
        }

        var color: Color {
            switch self {
            case .sing: .rsTextSecondary
            case .flip: .rsCaution
            case .copy: .rsRecord
            case .flipBack: .rsGood
            }
        }

        /// The flipped steps run the song backwards.
        var isReversed: Bool { self == .flip || self == .copy }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Strings.Help.Flow.title)
                .editorLabelStyle()

            TimelineView(.periodic(from: .now, by: 1.2)) { context in
                let active = reduceMotion
                    ? nil
                    : Int(context.date.timeIntervalSinceReferenceDate / 1.2) % Step.allCases.count

                HStack(alignment: .top, spacing: 6) {
                    ForEach(Step.allCases, id: \.rawValue) { step in
                        stepView(step, isLit: active == nil || active == step.rawValue)
                        if step != .flipBack {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.rsTextTertiary)
                                .padding(.top, 16)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: active)
            }

            Text(Strings.Help.Flow.caption)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
        .accessibilityElement(children: .combine)
    }

    private func stepView(_ step: Step, isLit: Bool) -> some View {
        VStack(spacing: 8) {
            MiniWaveform(isReversed: step.isReversed, isWobbly: step == .copy)
                .fill(step.color)
                .frame(height: 30)
                .opacity(isLit ? 1 : 0.3)
                .scaleEffect(isLit ? 1 : 0.92)

            Text(step.title)
                .font(.rsCaptionSmall)
                .foregroundColor(isLit ? .rsTextPrimary : .rsTextTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A short waveform with an unmistakable shape: a small bump, then a big one. Reversed, the big
/// one comes first, so the flip is visible at a glance.
nonisolated private struct MiniWaveform: Shape {
    let isReversed: Bool
    /// A copy is never quite the original; it gets a little unevenness.
    let isWobbly: Bool

    private static let levels: [CGFloat] = [
        0.15, 0.3, 0.45, 0.3, 0.2, 0.1, 0.25, 0.55, 0.85, 1, 0.9, 0.7, 0.45, 0.25, 0.12
    ]

    func path(in rect: CGRect) -> Path {
        var levels = isReversed ? Self.levels.reversed() : Self.levels
        if isWobbly {
            levels = levels.enumerated().map { index, level in
                min(1, level * (index % 2 == 0 ? 0.85 : 1.1))
            }
        }
        let barWidth = rect.width / CGFloat(levels.count * 2 - 1)
        var path = Path()
        for (index, level) in levels.enumerated() {
            let height = max(2, rect.height * level)
            let bar = CGRect(
                x: rect.minX + CGFloat(index) * barWidth * 2,
                y: rect.midY - height / 2,
                width: barWidth,
                height: height
            )
            path.addRoundedRect(in: bar, cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2))
        }
        return path
    }
}
