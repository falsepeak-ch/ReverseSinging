//
//  DubPlaybackView.swift
//  ReverseSinging
//
//  Program monitor: the scene playing back, with a scrubbable timeline
//  and the caption burned in as a subtitle.
//

import SwiftUI

struct DubPlaybackView: View {
    @ObservedObject var viewModel: DubViewModel
    let mode: DubPlaybackMode

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player: DubPlayer

    @StateObject private var scenePicture = DubScenePicture()
    @State private var sceneSamples: [Float] = []

    init(viewModel: DubViewModel, mode: DubPlaybackMode) {
        self.viewModel = viewModel
        self.mode = mode
        self.player = viewModel.scenePlayer
    }

    /// The line on screen right now — the same lookup the exporter uses to pick frames.
    private var activeLine: DubLine? {
        viewModel.pack.line(at: player.currentTime)
    }

    var body: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()

            VStack(spacing: 0) {
                hud
                program
                timeline
            }

            if player.isPreparing {
                ProcessingIndicator(message: Strings.Dub.loadingScene)
            }
        }
        .statusBarHidden()
        .animation(.easeInOut(duration: 0.2), value: activeLine?.slug)
        .task {
            scenePicture.configure(with: viewModel.pack)
            await viewModel.playScene(mode: mode)
        }
        .onDisappear {
            scenePicture.tearDown()
            player.stop()
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            isPlaying ? scenePicture.playScene(from: player.currentTime) : scenePicture.pauseScene()
        }
        // The mix is the master clock; the picture is corrected towards it.
        .onChange(of: player.currentTime) { _, time in
            scenePicture.resync(to: time)
        }
        .task(id: viewModel.pack.backingTrackURL) {
            guard let url = viewModel.pack.backingTrackURL else { return }
            sceneSamples = await WaveformSampler.shared.samples(from: url, buckets: 160)
        }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack(spacing: 12) {
            Button {
                player.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rsTextSecondary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.rsSurface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
                    )
            }

            Text(mode.displayName)
                .editorLabelStyle(mode == .myDub ? .rsGood : .rsHighlight)

            Spacer()

            if let line = activeLine {
                Text(String(format: "%03d", line.index))
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextTertiary)
            }
        }
        .padding(.horizontal, EditorMetrics.gutter)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.rsSurface1)
        .overlay(alignment: .bottom) { EditorRule() }
    }

    // MARK: - Program

    private var program: some View {
        ZStack(alignment: .bottom) {
            DubPicture(
                player: scenePicture.player,
                stillURL: activeLine.map { viewModel.pack.imageURL(for: $0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Only the still needs re-identifying per line; the video runs continuously.
            .id(scenePicture.player == nil ? (activeLine?.slug ?? "black") : "video")

            if let line = activeLine {
                subtitle(for: line)
            }
        }
        .frame(maxHeight: .infinity)
        .cinemaVignette()
        .filmGrain(opacity: 0.06)
    }

    private func subtitle(for line: DubLine) -> some View {
        VStack(spacing: 6) {
            DubCharacterPlate(
                character: line.character,
                color: DubCharacterStyle.color(for: line.character, in: viewModel.pack.characters)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.rsSurface0.opacity(0.6))

            Text(line.caption)
                .font(.rsBodyLarge)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .shadow(color: .black.opacity(0.9), radius: 5)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(spacing: 10) {
            if !sceneSamples.isEmpty {
                DubWaveformView(
                    samples: sceneSamples,
                    progress: progressFraction,
                    height: 40
                )
                .padding(.horizontal, EditorMetrics.gutter)
            }

            EditorTickRuler(duration: player.duration)
                .padding(.horizontal, EditorMetrics.gutter)

            EditorTrack(progress: progressFraction)
                .padding(.horizontal, EditorMetrics.gutter)

            HStack {
                Text(timecode(player.currentTime))
                    .font(.rsTimecode)
                    .foregroundColor(.rsTextPrimary)

                Spacer()

                Button {
                    if player.isPlaying {
                        player.stop()
                    } else {
                        player.play(from: 0)
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.rsTextPrimary)
                        .frame(width: 54, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.rsSurface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.rsStrokeStrong, lineWidth: EditorMetrics.hairline)
                        )
                }

                Spacer()

                Text(timecode(player.duration))
                    .font(.rsTimecode)
                    .foregroundColor(.rsTextTertiary)
            }
            .padding(.horizontal, EditorMetrics.gutter)
        }
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    private var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(1, player.currentTime / player.duration)
    }

    private func timecode(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let frames = Int((time - floor(time)) * 24)
        return String(format: "%02d:%02d:%02d", minutes, seconds, frames)
    }
}
