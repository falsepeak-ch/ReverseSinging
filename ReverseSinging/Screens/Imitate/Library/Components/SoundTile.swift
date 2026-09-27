//
//  SoundTile.swift
//  ReverseSinging
//
//  One sound in the library grid
//

import DubScoring
import SwiftUI

/// The sound's illustration and name, difficulty, and personal best.
struct SoundTile: View {
    let sound: ImitationSound
    let best: Double?
    let grade: DubGrade?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ImitationSoundArtwork(sound: sound, size: 50)
                    .frame(height: 50)

                Text(sound.name)
                    .font(.rsButtonSmall)
                    .foregroundColor(.rsTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    DifficultyDots(level: sound.difficulty)
                    Spacer(minLength: 0)
                    bestLabel
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .editorPanel(.rsSurface1, stroke: grade.map { $0.color.opacity(0.45) } ?? .rsStroke)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var bestLabel: some View {
        if let best, let grade {
            Text("\(Int(best.rounded()))")
                .font(.rsTimecodeSmall)
                .foregroundColor(grade.color)
                .accessibilityLabel("\(Strings.Imitate.best) \(Int(best.rounded()))")
        } else {
            Text(Strings.Imitate.untried)
                .font(.rsLabelSmall)
                .textCase(.uppercase)
                .foregroundColor(.rsTextTertiary)
        }
    }
}

/// Shared artwork for library tiles, the challenge stage, and camera badges.
struct ImitationSoundArtwork: View {
    let sound: ImitationSound
    let size: CGFloat

    var body: some View {
        Group {
            if let artworkName = sound.artworkName {
                Image(artworkName)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(sound.emoji)
                    .font(.system(size: size * 0.84))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// One to three dots: how hard a sound is to pull off.
struct DifficultyDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= level ? Color.rsTextSecondary : Color.rsSurface3)
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("\(Strings.Imitate.difficulty) \(level)")
    }
}
