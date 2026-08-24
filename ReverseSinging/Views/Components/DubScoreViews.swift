//
//  DubScoreViews.swift
//  ReverseSinging
//
//  How a dub scored, shown three ways: a chip, a card, a panel
//

import SwiftUI

// MARK: - Grade Colour

extension DubGrade {
    /// The one place a grade becomes a colour, so the chip beside a line and the panel at the
    /// top of the screen can never disagree about what 74 looks like.
    var color: Color {
        switch self {
        case .perfect, .great: return .rsGood
        case .good:            return .rsHighlight
        case .close:           return .rsCaution
        case .rough:           return .rsRecord
        }
    }
}

extension DubLineScore {
    var grade: DubGrade { DubGrade.forScore(overall) }
}

extension DubSceneScore {
    var grade: DubGrade { DubGrade.forScore(overall) }
}

// MARK: - Line Chip

/// A line's score as a two-character badge, sized to sit in a list row without moving it.
struct DubScoreChip: View {
    let score: DubLineScore

    var body: some View {
        Text(score.grade.badge)
            .font(.rsTimecodeSmall)
            .foregroundColor(score.grade.color)
            .frame(minWidth: 26)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(score.grade.color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(score.grade.color.opacity(0.4), lineWidth: EditorMetrics.hairline)
            )
            .accessibilityLabel("\(Strings.Dub.Score.lineTitle): \(Int(score.overall.rounded()))")
    }
}

// MARK: - Component Bars

/// One of the three things a take is judged on, as a labelled rail.
///
/// The number and the bar say the same thing on purpose: the bar is read at a glance across
/// three rows, the number is what you compare against your last take.
struct DubScoreBar: View {
    let label: String
    let value: Double
    var tint: Color = .rsTextSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .editorLabelStyle(.rsTextTertiary)

                Spacer()

                Text(String(format: "%03d", Int(value.rounded())))
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.rsSurface3)
                        .frame(height: 3)

                    Rectangle()
                        .fill(tint)
                        .frame(width: geometry.size.width * min(1, max(0, value / 100)), height: 3)
                }
            }
            .frame(height: 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Int(value.rounded()))")
    }
}

// MARK: - Take Card

/// The verdict on the take that was just performed, shown under the record transport.
///
/// Compact on purpose. It appears the moment a take is saved, while the performer is still
/// deciding whether to go again, so it has to answer "was that any good" without covering the
/// picture or pushing the record button off the screen.
struct DubTakeScoreCard: View {
    let score: DubLineScore

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(String(format: "%d", Int(score.overall.rounded())))
                    .font(.rsTimecode)
                    .foregroundColor(score.grade.color)

                Text(score.grade.badge)
                    .font(.rsLabelSmall)
                    .foregroundColor(score.grade.color.opacity(0.8))
            }
            .frame(width: 40)

            Rectangle()
                .fill(Color.rsStroke)
                .frame(width: EditorMetrics.hairline, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(score.grade.title)
                    .font(.rsButtonSmall)
                    .foregroundColor(.rsTextPrimary)

                // Three fixed columns rather than a run-on line of figures. Set as a sentence
                // it wrapped to two lines in the longer locales and made the card grow into
                // the transport; as columns it is the same height in every language, and the
                // numbers line up under their labels where they can be compared at a glance.
                HStack(alignment: .top, spacing: 14) {
                    component(Strings.Dub.Score.timing, score.timing)
                    component(Strings.Dub.Score.pacing, score.pacing)
                    component(Strings.Dub.Score.delivery, score.delivery)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .editorPanel(.rsSurface2)
    }

    private func component(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.rsLabelSmall)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(.rsTextTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(String(format: "%d", Int(value.rounded())))
                .font(.rsTimecodeSmall)
                .foregroundColor(DubGrade.forScore(value).color.opacity(0.9))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Int(value.rounded()))")
    }
}

// MARK: - Scene Panel

/// The whole scene's standing: one headline number, the three components behind it, and the
/// two lines worth acting on.
struct DubSceneScorePanel: View {
    let score: DubSceneScore
    /// Looks a line up by slug, so the panel can name the best and weakest takes without
    /// having to be handed the pack.
    let line: (String) -> DubLine?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if score.recordedLines == 0 {
                Text(Strings.Dub.Score.notScoredYet)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextTertiary)
            } else {
                components
                highlights
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if score.recordedLines > 0 {
                Text(String(format: "%d", Int(score.overall.rounded())))
                    .font(.rsTimecodeLarge)
                    .foregroundColor(score.grade.color)
            } else {
                Text("—")
                    .font(.rsTimecodeLarge)
                    .foregroundColor(.rsTextTertiary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(score.recordedLines > 0 ? score.grade.title : Strings.Dub.Score.sceneTitle)
                    .font(.rsButtonMedium)
                    .foregroundColor(.rsTextPrimary)

                Text(String(
                    format: Strings.Dub.Score.progress,
                    score.recordedLines,
                    score.totalLines
                ))
                .font(.rsMeta)
                .foregroundColor(.rsTextTertiary)
            }

            Spacer(minLength: 0)
        }
    }

    private var components: some View {
        VStack(spacing: 10) {
            DubScoreBar(
                label: Strings.Dub.Score.timing,
                value: score.timing,
                tint: DubGrade.forScore(score.timing).color
            )
            DubScoreBar(
                label: Strings.Dub.Score.pacing,
                value: score.pacing,
                tint: DubGrade.forScore(score.pacing).color
            )
            DubScoreBar(
                label: Strings.Dub.Score.delivery,
                value: score.delivery,
                tint: DubGrade.forScore(score.delivery).color
            )
        }
    }

    /// Best and weakest, but only once there is more than one take — with a single line
    /// recorded they are the same take, and naming it twice reads as a bug.
    @ViewBuilder
    private var highlights: some View {
        if score.recordedLines > 1,
           let best = score.best,
           let weakest = score.weakest,
           best.slug != weakest.slug {
            VStack(spacing: 6) {
                EditorRule()

                highlight(label: Strings.Dub.Score.best, score: best)
                highlight(label: Strings.Dub.Score.weakest, score: weakest)
            }
        }
    }

    private func highlight(label: String, score: DubLineScore) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .editorLabelStyle(.rsTextTertiary)

            Text(line(score.slug)?.caption ?? score.slug)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            DubScoreChip(score: score)
        }
    }
}

// MARK: - Preview

#Preview {
    let lines = (1...4).map { index in
        DubLine(
            index: index,
            slug: String(format: "%03d_Tester", index),
            character: "Tester",
            caption: "A line of dialogue number \(index)",
            imageFile: "", referenceAudioFile: "",
            startTime: 0, duration: 1
        )
    }
    let scores = [
        DubLineScore(slug: "001_Tester", timing: 96, pacing: 88, delivery: 74),
        DubLineScore(slug: "002_Tester", timing: 62, pacing: 71, delivery: 66),
        DubLineScore(slug: "003_Tester", timing: 31, pacing: 44, delivery: 52)
    ]

    return ScrollView {
        VStack(spacing: 16) {
            DubSceneScorePanel(
                score: DubSceneScore(lines: scores, totalLines: 12),
                line: { slug in lines.first { $0.slug == slug } }
            )
            DubTakeScoreCard(score: scores[0])
            DubTakeScoreCard(score: scores[2])
        }
        .padding()
    }
    .background(Color.rsSurface0)
}
