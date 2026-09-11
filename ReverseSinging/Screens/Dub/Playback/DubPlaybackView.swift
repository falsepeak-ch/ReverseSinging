//
//  DubPlaybackView.swift
//  ReverseSinging
//
//  Program monitor: the scene playing back, with a scrubbable timeline
//  and the caption burned in as a subtitle.
//

import SwiftUI
import DubAudio
import DubloonFoundation

struct DubPlaybackView: View {
    @StateObject private var viewModel: DubPlaybackViewModel
    /// The clock, observed here rather than through the view model: it ticks many times a
    /// second, and only this screen's timeline needs to hear about every tick.
    @ObservedObject private var player: DubPlayer

    @Environment(\.dismiss) private var dismiss

    init(session: DubSessionViewModel, mode: DubPlaybackMode) {
        _viewModel = StateObject(wrappedValue: DubPlaybackViewModel(session: session, mode: mode))
        self.player = session.scenePlayer
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
        .animation(.easeInOut(duration: 0.2), value: viewModel.captionLine?.slug)
        .animation(.easeInOut(duration: 0.2), value: viewModel.boothReel.currentSlug)
        .task { await viewModel.start() }
        .onDisappear { viewModel.onDisappear() }
        .onChange(of: player.playbackAnchor) { _, anchor in
            viewModel.playbackAnchorDidChange(anchor)
        }
        .onChange(of: player.currentTime) { _, time in
            viewModel.currentTimeDidChange(time)
        }
        .task(id: viewModel.pack.backingTrackURL) {
            await viewModel.loadSceneWaveform()
        }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.close()
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

            Text(viewModel.mode.displayName)
                .editorLabelStyle(viewModel.mode == .myDub ? .rsGood : .rsHighlight)

            Spacer()

            if let line = viewModel.captionLine ?? viewModel.pictureLine {
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
                player: viewModel.scenePicture.player,
                stillURL: viewModel.pictureLine.map { viewModel.pack.imageURL(for: $0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Only the still needs re-identifying per line; the video runs continuously.
            .id(viewModel.scenePicture.player == nil ? (viewModel.pictureLine?.slug ?? "black") : "video")

            if let line = viewModel.captionLine {
                subtitle(for: line)
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity)
        .cinemaVignette()
        .filmGrain(opacity: 0.06)
        // The booth, wherever a line has footage. Above the vignette and the grain: it is a
        // monitor on the picture, not part of it. The top corner rather than the bottom one
        // the record screen uses, because the subtitle lives along the foot of this picture
        // and a caption is not something to cover with a face.
        .overlay(alignment: .topTrailing) {
            if viewModel.boothReel.currentSlug != nil {
                BoothReelMonitor(reel: viewModel.boothReel)
                    .padding(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
            }
        }
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
            scrubber

            HStack {
                Text(player.currentTime.rsClockFrames)
                    .font(.rsTimecode)
                    .foregroundColor(.rsTextPrimary)

                Spacer()

                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
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
                .accessibilityLabel(player.isPlaying ? Strings.Dub.pause : Strings.Dub.play)

                Spacer()

                Text(player.duration.rsClockFrames)
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

    /// The waveform, the ruler and the track, as one thing a finger can land anywhere on.
    ///
    /// Tap or drag: the head goes where the finger is and stays under it. Playback is held
    /// for as long as the finger is down and picked up again from the new place, so dragging
    /// through a scene is silent rather than a stutter of restarts. Every part of this bay
    /// already draws the same position, so every part of it is the scrubber.
    private var scrubber: some View {
        VStack(spacing: 10) {
            if !viewModel.sceneSamples.isEmpty {
                DubWaveformView(
                    samples: viewModel.sceneSamples,
                    progress: viewModel.progressFraction,
                    height: 40
                )
            }

            EditorTickRuler(duration: player.duration)

            EditorTrack(progress: viewModel.progressFraction)
        }
        .padding(.horizontal, EditorMetrics.gutter)
        .contentShape(Rectangle())
        .overlay {
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(width: geometry.size.width, inset: EditorMetrics.gutter))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Strings.Dub.timeline)
        .accessibilityValue(player.currentTime.rsClockFrames)
        .accessibilityAdjustableAction { direction in
            let step: TimeInterval = 5
            switch direction {
            case .increment: viewModel.seek(by: step)
            case .decrement: viewModel.seek(by: -step)
            @unknown default: break
            }
        }
    }

    /// - Parameter inset: the gutter either side of the track, so a finger on the margin
    ///   reads as the nearest end rather than as somewhere off the scene.
    private func scrubGesture(width: CGFloat, inset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let span = width - inset * 2
                guard span > 0 else { return }

                let fraction = min(max(0, (value.location.x - inset) / span), 1)
                viewModel.scrub(to: Double(fraction))
            }
            .onEnded { _ in
                viewModel.endScrub()
            }
    }
}
