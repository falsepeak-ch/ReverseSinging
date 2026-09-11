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
    @ObservedObject var viewModel: DubViewModel
    let mode: DubPlaybackMode

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player: DubPlayer

    @StateObject private var scenePicture = DubScenePicture()
    /// The performer's own footage, running alongside. Left empty in `.original`: that mode
    /// is the film, and the film has nobody filming themselves in the corner.
    @StateObject private var boothReel = DubBoothReel()
    @State private var sceneSamples: [Float] = []

    /// True from the first touch on the timeline to the lift. The scene is held while the
    /// finger is down and picked up again after, if it was running before.
    @State private var isScrubbing = false
    @State private var wasPlayingBeforeScrub = false

    init(viewModel: DubViewModel, mode: DubPlaybackMode) {
        self.viewModel = viewModel
        self.mode = mode
        self.player = viewModel.scenePlayer
    }

    /// The line whose picture is on screen right now. The same lookup the exporter uses to
    /// pick slideshow frames, so what plays here is what gets rendered.
    private var pictureLine: DubLine? {
        viewModel.pack.line(at: player.currentTime)
    }

    /// The caption to burn in right now, or nil in a gap.
    ///
    /// Not the same question as `pictureLine`: a still has to show *something* for every
    /// frame of the scene, but a subtitle that stays up through the silence between two lines
    ///, having gone up a beat or two before the character opened their mouth, reads as
    /// broken. See `DubPack.captionLine(at:)`.
    private var captionLine: DubLine? {
        viewModel.pack.captionLine(at: player.currentTime)
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
        .animation(.easeInOut(duration: 0.2), value: captionLine?.slug)
        .animation(.easeInOut(duration: 0.2), value: boothReel.currentSlug)
        .task {
            scenePicture.configure(with: viewModel.pack)
            if mode == .myDub {
                boothReel.configure(with: viewModel.pack, slugs: viewModel.boothSlugs)
            }
            await viewModel.playScene(mode: mode)
        }
        .onDisappear {
            scenePicture.tearDown()
            boothReel.tearDown()
            player.stop()
        }
        // The anchor rather than `isPlaying`: a seek mid-play restarts the engine on a new
        // deadline without ever passing through "not playing", and the pictures have to move
        // to the new deadline with it.
        .onChange(of: player.playbackAnchor) { _, anchor in
            if let anchor {
                scenePicture.playScene(at: anchor)
            } else {
                scenePicture.pauseScene()
            }
            boothReel.follow(time: player.currentTime, anchor: anchor)
        }
        // The mix is the master clock; the pictures are corrected towards it. Held, the head
        // can still be moved, and the frame under it has to follow.
        .onChange(of: player.currentTime) { _, time in
            if player.isPlaying {
                scenePicture.resync(to: time)
            } else {
                scenePicture.showFrame(at: time)
            }
            boothReel.follow(time: time, anchor: player.playbackAnchor)
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

            if let line = captionLine ?? pictureLine {
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
                stillURL: pictureLine.map { viewModel.pack.imageURL(for: $0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Only the still needs re-identifying per line; the video runs continuously.
            .id(scenePicture.player == nil ? (pictureLine?.slug ?? "black") : "video")

            if let line = captionLine {
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
            if boothReel.currentSlug != nil {
                BoothReelMonitor(reel: boothReel)
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
                    if player.isPlaying {
                        player.pause()
                    } else {
                        player.resume()
                    }
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
            if !sceneSamples.isEmpty {
                DubWaveformView(
                    samples: sceneSamples,
                    progress: progressFraction,
                    height: 40
                )
            }

            EditorTickRuler(duration: player.duration)

            EditorTrack(progress: progressFraction)
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
            case .increment: player.seek(to: player.currentTime + step)
            case .decrement: player.seek(to: player.currentTime - step)
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
                guard span > 0, player.duration > 0 else { return }

                if !isScrubbing {
                    isScrubbing = true
                    wasPlayingBeforeScrub = player.isPlaying
                    player.pause()
                }

                let fraction = min(max(0, (value.location.x - inset) / span), 1)
                player.seek(to: Double(fraction) * player.duration)
            }
            .onEnded { _ in
                guard isScrubbing else { return }
                isScrubbing = false
                if wasPlayingBeforeScrub { player.resume() }
                HapticManager.shared.light()
            }
    }

    private var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(1, player.currentTime / player.duration)
    }
}
