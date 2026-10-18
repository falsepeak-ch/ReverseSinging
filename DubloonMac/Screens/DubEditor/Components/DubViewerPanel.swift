//
//  DubViewerPanel.swift
//  DubloonMac
//
//  The viewer: one line in the recording bay, or the whole scene in the program monitor
//

import SwiftUI
import TipKit
import DubAudio

struct DubViewerPanel: View {
    @ObservedObject var viewModel: DubEditorViewModel
    private let playDubTip = DubPlayDubTip()

    var body: some View {
        VStack(spacing: 0) {
            ProPanelHeader(title: MacStrings.Panel.viewer, subtitle: subtitle) {
                Picker(MacStrings.Panel.viewer, selection: Binding(
                    get: { viewModel.mode },
                    set: { mode in
                        if mode == .myDub { playDubTip.invalidate(reason: .actionPerformed) }
                        viewModel.setMode(mode)
                    }
                )) {
                    ForEach(DubViewerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
                .disabled(viewModel.record.isRecording)
                .popoverTip(playDubTip, arrowEdge: .top)
            }

            if let playback = viewModel.playback {
                DubSceneViewer(playback: playback, player: viewModel.session.scenePlayer)
                    .id(playback.mode)
            } else {
                DubLineViewer(viewModel: viewModel, record: viewModel.record, session: viewModel.session)
            }
        }
        .background(Color.proViewer)
    }

    private var subtitle: String? {
        viewModel.pack.title
    }
}

// MARK: - Line

/// The recording bay: the line's picture, the words to say, the reference against the take,
/// and the transport.
private struct DubLineViewer: View {
    @ObservedObject var viewModel: DubEditorViewModel
    @ObservedObject var record: DubRecordViewModel
    @ObservedObject var session: DubSessionViewModel
    @ObservedObject private var booth = BoothCamPreference.shared

    private let recordTip = DubRecordTip()

    var body: some View {
        if let line = session.currentLine {
            VStack(spacing: 0) {
                picture(for: line)
                caption(for: line)
                waveform(for: line)
                transport(for: line)
            }
            .animation(.easeInOut(duration: 0.2), value: record.isRecording)
        }
    }

    private func picture(for line: DubLine) -> some View {
        ZStack {
            Color.proViewer

            DubPicture(player: record.scenePicture.player, stillURL: session.pack.imageURL(for: line))
                .id(record.scenePicture.player == nil ? line.slug : "video")
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    DubCharacterPlate(character: line.character, color: characterColor(for: line))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.rsSurface0.opacity(0.72))
                        .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    if record.isRecording {
                        recBadge.padding(12)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if booth.isEnabled, record.booth.isUsable {
                        BoothMonitor(
                            recorder: record.booth,
                            level: record.recordingLevel,
                            isRecording: record.isRecording,
                            playbackURL: session.boothPlaybackURL
                        )
                        .padding(12)
                        .transition(.opacity)
                    }
                }
                .overlay {
                    if record.isRecording {
                        Rectangle()
                            .strokeBorder(Color.rsRecord, lineWidth: 2)
                    }
                }

            CountdownOverlay(value: record.countdown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var recBadge: some View {
        HStack(spacing: 6) {
            EditorRecordDot(isActive: true)
            Text(Strings.Main.State.recording)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.rsRecord)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.6)))
    }

    private func caption(for line: DubLine) -> some View {
        VStack(spacing: 8) {
            DubCharacterPlate(character: line.character, color: characterColor(for: line), isProminent: true)

            Text(line.caption)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.rsTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 720)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.rsSurface3)
                    Rectangle()
                        .fill(record.isOverLength(line) ? Color.rsCaution : Color.rsRecord)
                        .frame(width: geometry.size.width * record.pacingFraction(for: line))
                }
            }
            .frame(height: 2)
            .frame(maxWidth: 720)
            .opacity(record.isRecording ? 1 : 0.35)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    private func waveform(for line: DubLine) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.Dub.referenceTrack)
                    .editorLabelStyle(.rsTextTertiary)
                Text(Strings.Dub.yourTake)
                    .editorLabelStyle(record.isRecording || !record.takeSamples.isEmpty ? .rsRecord : .rsSurface3)
            }
            .frame(width: 92, alignment: .leading)

            DubWaveformView(
                samples: record.referenceSamples,
                overlay: record.takeOverlay,
                overlayTint: .rsRecord,
                progress: record.waveformProgress(for: line),
                height: 40,
                onTap: { record.toggleReferencePreview() }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    private func transport(for line: DubLine) -> some View {
        HStack(spacing: 8) {
            Text(record.timerText(for: line))
                .font(.rsTimecodeSmall)
                .foregroundColor(record.isOverLength(line) ? .rsCaution : .rsTextSecondary)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 100, alignment: .leading)

            Spacer()

            ProTransportButton(icon: "backward.end.fill", label: MacStrings.Menu.previousLine) {
                record.goToPreviousLine()
            }
            .disabled(!record.canGoToPreviousLine)

            ProTransportButton(
                icon: session.isPreviewingReference ? "stop.fill" : "speaker.wave.2.fill",
                label: MacStrings.Menu.listen,
                isActive: session.isPreviewingReference
            ) {
                record.toggleReferencePreview()
            }
            .disabled(record.isRecording)

            ProRecordButton(
                isRecording: record.isRecording,
                isCountingIn: record.countdown != nil,
                level: record.recordingLevel,
                size: 34,
                label: record.isRecording ? Strings.Dub.stop : Strings.Dub.recordTake
            ) {
                recordTip.invalidate(reason: .actionPerformed)
                record.toggleRecording()
            }
            .padding(.horizontal, 6)
            .popoverTip(recordTip, arrowEdge: .bottom)

            ProTransportButton(icon: "play.fill", label: MacStrings.Menu.playTake) {
                record.playCurrentTake()
            }
            .disabled(!record.canPlayTake(of: line))

            ProTransportButton(icon: "forward.end.fill", label: MacStrings.Menu.nextLine) {
                record.goToNextLine()
            }
            .disabled(record.isRecording || record.isOnLastLine)

            Spacer()

            Group {
                if record.showsScoreCard, let score = session.latestScore {
                    DubScoreChip(score: score)
                } else {
                    Text(record.isRecording ? Strings.Dub.recordingHint : Strings.Dub.listenHint)
                        .font(.rsCaptionSmall)
                        .foregroundColor(.rsTextTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(minWidth: 0, maxWidth: 130, alignment: .trailing)
                .layoutPriority(-1)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color.rsSurface2)
        .overlay(alignment: .top) { EditorRule() }
    }

    private func characterColor(for line: DubLine) -> Color {
        DubCharacterStyle.color(for: line.character, in: session.pack.characters)
    }
}

// MARK: - Scene

/// The program monitor: the scene with the mix, the booth reel and burned-in captions.
private struct DubSceneViewer: View {
    @ObservedObject var playback: DubPlaybackViewModel
    /// The clock, observed directly for every tick.
    @ObservedObject var player: DubPlayer

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.proViewer

                DubPicture(
                    player: playback.scenePicture.player,
                    stillURL: playback.pictureLine.map { playback.pack.imageURL(for: $0) }
                )
                .id(playback.scenePicture.player == nil ? (playback.pictureLine?.slug ?? "black") : "video")
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    if let line = playback.captionLine {
                        subtitle(for: line)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if playback.boothReel.currentSlug != nil {
                        BoothReelMonitor(reel: playback.boothReel)
                            .padding(12)
                            .transition(.opacity)
                    }
                }

                if player.isPreparing {
                    ProgressView(Strings.Dub.loadingScene)
                        .controlSize(.small)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.6)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            transport
        }
        .animation(.easeInOut(duration: 0.2), value: playback.captionLine?.slug)
        .animation(.easeInOut(duration: 0.2), value: playback.boothReel.currentSlug)
        .task { await playback.start() }
        .onChange(of: player.playbackAnchor) { _, anchor in playback.playbackAnchorDidChange(anchor) }
        .onChange(of: player.currentTime) { _, time in playback.currentTimeDidChange(time) }
    }

    private func subtitle(for line: DubLine) -> some View {
        VStack(spacing: 6) {
            DubCharacterPlate(
                character: line.character,
                color: DubCharacterStyle.color(for: line.character, in: playback.pack.characters)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.rsSurface0.opacity(0.6))

            Text(line.caption)
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.9), radius: 5)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 22)
    }

    private var transport: some View {
        HStack(spacing: 8) {
            Text(player.currentTime.proTimecode)
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextPrimary)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 100, alignment: .leading)

            Spacer()

            ProTransportButton(icon: "backward.end.fill", label: MacStrings.Menu.previousLine) {
                player.seek(to: 0)
            }

            ProTransportButton(icon: "gobackward.5", label: "−5s") {
                playback.seek(by: -5)
            }

            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
                    .frame(width: 44, height: 30)
                    .background(RoundedRectangle(cornerRadius: ProMetrics.radius).fill(Color.rsSurface3))
                    .overlay(
                        RoundedRectangle(cornerRadius: ProMetrics.radius)
                            .strokeBorder(Color.rsStrokeStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(ProPressStyle())
            .help(player.isPlaying ? Strings.Dub.pause : Strings.Dub.play)

            ProTransportButton(icon: "goforward.5", label: "+5s") {
                playback.seek(by: 5)
            }

            Spacer()

            Text(player.duration.proTimecode)
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextTertiary)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 100, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color.rsSurface2)
        .overlay(alignment: .top) { EditorRule() }
    }
}
