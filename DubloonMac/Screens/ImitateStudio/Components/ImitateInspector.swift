//
//  ImitateInspector.swift
//  DubloonMac
//
//  The selected sound, the verdict on the last attempt, and where the sound came from
//

import SwiftUI
import DubScoring

struct ImitateInspector: View {
    @ObservedObject var viewModel: ImitateStudioViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let challenge = viewModel.challenge {
                    soundSection(challenge.sound)

                    if challenge.phase == .result, let score = challenge.score {
                        resultSection(score, isNewBest: challenge.isNewBest)
                    }

                    creditSection(challenge.sound)
                }
            }
        }
        .background(Color.rsSurface1)
    }

    private func soundSection(_ sound: ImitationSound) -> some View {
        ProInspectorSection(title: sound.category.title) {
            HStack(spacing: 12) {
                ImitationSoundArtwork(sound: sound, size: 44)
                    .frame(width: 44, height: 44)
                Text(sound.name)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)
            }

            ProInspectorRow(label: MacStrings.Panel.duration, value: sound.duration.proShortTime)
            HStack {
                Text(Strings.Imitate.difficulty)
                    .font(.rsMeta)
                    .foregroundColor(.rsTextSecondary)
                Spacer()
                DifficultyMeter(level: sound.difficulty)
            }

            if let best = viewModel.library.best(for: sound), let grade = viewModel.library.grade(for: sound) {
                ProInspectorRow(
                    label: Strings.Imitate.best,
                    value: "\(Int(best.rounded()))  \(grade.badge)",
                    valueColor: grade.color
                )
            } else {
                ProInspectorRow(label: Strings.Imitate.best, value: Strings.Imitate.untried, valueColor: .rsTextTertiary)
            }
        }
    }

    private func resultSection(_ score: ImitationScore, isNewBest: Bool) -> some View {
        ProInspectorSection(title: Strings.Dub.Score.slate) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(score.overall.rounded()))")
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .foregroundColor(score.grade.color)
                Text(score.grade.title)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextSecondary)
                Spacer()
                if isNewBest {
                    Text(Strings.Imitate.newBest)
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(.rsGood)
                }
            }

            ImitateScoreRadar(score: score)

            ImitationScoreParts(score: score)
        }
    }

    private func creditSection(_ sound: ImitationSound) -> some View {
        ProInspectorSection(title: Strings.Dub.attribution) {
            Link(destination: URL(string: "https://freesound.org/s/\(sound.freesoundID)/")!) {
                Text(verbatim: "Freesound #\(sound.freesoundID)")
            }
            .font(.rsMeta)
            Text("\(sound.author) · \(sound.license)")
                .font(.rsCaptionSmall)
                .foregroundColor(.rsTextTertiary)
        }
    }
}
