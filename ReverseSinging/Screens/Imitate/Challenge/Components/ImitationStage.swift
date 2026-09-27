//
//  ImitationStage.swift
//  ReverseSinging
//
//  The big panel: the sound's artwork or your face, and the verdict when it lands
//

import DubScoring
import SwiftUI

/// The top of the challenge screen.
///
/// Before an attempt it shows the sound (or, with Booth Cam on, the performer), lit red
/// while recording. After it, the score counts up and the stamp slams down on top, over the
/// attempt's own footage when there is some.
struct ImitationStage: View {
    @ObservedObject var viewModel: ImitationChallengeViewModel
    @ObservedObject private var preference = BoothCamPreference.shared

    @State private var shownScore: Double = 0

    var body: some View {
        ZStack {
            background

            if viewModel.phase == .result, let score = viewModel.score, let verdict = viewModel.verdict {
                result(score: score, verdict: verdict)
                    .transition(.opacity)
            } else if viewModel.phase == .scoring {
                VStack(spacing: 10) {
                    ProgressView().tint(.rsTextPrimary)
                    Text(Strings.Imitate.scoring)
                        .font(.rsCaption)
                        .foregroundColor(.rsTextSecondary)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: EditorMetrics.radius).fill(Color.rsSurface0.opacity(0.7)))
            }

            if let start = viewModel.confettiStart, viewModel.phase == .result {
                ConfettiBurst(seed: viewModel.confettiSeed, start: start)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EditorMetrics.radiusLarge, style: .continuous)
                .strokeBorder(
                    viewModel.phase == .recording ? Color.rsRecord : Color.rsStroke,
                    lineWidth: viewModel.phase == .recording ? 3 : EditorMetrics.hairline
                )
        )
        .overlay(alignment: .topLeading) {
            if showsCamera || viewModel.boothPlaybackURL != nil {
                soundBadge.padding(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.phase == .recording)
    }

    // MARK: - Background

    private var showsCamera: Bool {
        preference.isEnabled && viewModel.booth.isPreviewing && viewModel.phase != .result
    }

    @ViewBuilder
    private var background: some View {
        if viewModel.phase == .result, let url = viewModel.boothPlaybackURL {
            BoothPlaybackView(url: url)
                .overlay(Color.rsSurface0.opacity(0.45))
        } else if showsCamera {
            BoothPreviewView(session: viewModel.booth.session, isMirrored: preference.mirrorsPreview)
        } else {
            Color.rsSurface1
                .overlay {
                    ImitationSoundArtwork(sound: viewModel.sound, size: 160)
                        .scaleEffect(artworkScale)
                        .animation(.easeOut(duration: 0.08), value: artworkScale)
                        .opacity(viewModel.phase == .result ? 0.25 : 1)
                }
        }
    }

    /// The artwork breathes with whatever is playing or being recorded.
    private var artworkScale: CGFloat {
        switch viewModel.phase {
        case .recording: return 1 + CGFloat(viewModel.level) * 0.25
        default: return viewModel.playingClip == .reference ? 1.08 : 1
        }
    }

    private var soundBadge: some View {
        HStack(spacing: 6) {
            ImitationSoundArtwork(sound: viewModel.sound, size: 24)
            Text(viewModel.sound.name)
                .font(.rsCaption)
                .foregroundColor(.rsTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.rsSurface0.opacity(0.75)))
    }

    // MARK: - Result

    private func result(score: ImitationScore, verdict: ImitationVerdict) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 2) {
                Text("\(Int(shownScore.rounded()))")
                    .font(.system(size: 88, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(.rsTextPrimary)
                    .contentTransition(.numericText(value: shownScore))

                if viewModel.isNewBest {
                    Text(Strings.Imitate.newBest)
                        .font(.rsCaption)
                        .foregroundColor(.rsGood)
                        .textCase(.uppercase)
                }
            }

            VerdictStamp(verdict: verdict) { viewModel.stampDidLand() }
        }
        .task(id: score.overall) {
            shownScore = 0
            withAnimation(.easeOut(duration: 0.8)) { shownScore = score.overall }
        }
    }
}

/// The parts the attempt was judged on, as rails.
struct ImitationScoreParts: View {
    let score: ImitationScore

    var body: some View {
        let tint = score.grade.color
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 12) {
            DubScoreBar(label: Strings.Imitate.Part.rhythm, value: score.rhythm, tint: tint)
            if let pitch = score.pitch {
                DubScoreBar(label: Strings.Imitate.Part.pitch, value: pitch, tint: tint)
            }
            DubScoreBar(label: Strings.Imitate.Part.tone, value: score.tone, tint: tint)
            DubScoreBar(label: Strings.Imitate.Part.duration, value: score.duration, tint: tint)
        }
        .frame(minHeight: 40)
    }
}
