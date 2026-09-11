//
//  DubRecordView.swift
//  ReverseSinging
//
//  Line-by-line dubbing, laid out like a recording bay: HUD above the
//  picture, subtitle plate below it, transport along the bottom.
//

import SwiftUI
import TipKit

struct DubRecordView: View {
    @ObservedObject var session: DubSessionViewModel
    @StateObject private var viewModel: DubRecordViewModel
    @ObservedObject private var scoring = DubScoringPreference.shared
    @ObservedObject private var booth = BoothCamPreference.shared
    @Environment(\.dismiss) private var dismiss

    /// The first-run coaching, one at a time. See `DubTips`.
    private let recordTip = DubRecordTip()
    private let boothTip = DubBoothTip()

    init(session: DubSessionViewModel) {
        self.session = session
        _viewModel = StateObject(wrappedValue: DubRecordViewModel(session: session))
    }

    var body: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()

            if let line = session.currentLine {
                VStack(spacing: 0) {
                    hud(for: line)

                    picture(for: line)

                    waveformBay(for: line)

                    subtitlePlate(for: line)

                    scoreBay

                    transportBar(for: line)
                }
            }

            CountdownOverlay(value: viewModel.countdown)
        }
        .statusBarHidden()
        .animation(.easeInOut(duration: 0.2), value: session.currentLineIndex)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
        .animation(.rsSpring, value: session.latestScore)
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: $viewModel.showPermissionAlert) {
            Button(Strings.Main.Alert.settings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Main.Alert.microphoneRequiredMessage)
        }
        .boothCamPrimer(isPresented: $viewModel.isBoothPrimerPresented) {
            viewModel.boothPrimerDidEnable()
        }
        .dubTipStyle()
        .advancesDubTips(past: 0, when: recordTip)
        .advancesDubTips(past: 1, when: boothTip)
        .onChange(of: booth.isEnabled, initial: true) { _, isOn in
            viewModel.boothPreferenceDidChange(isOn: isOn)
        }
        .onAppear { viewModel.onAppear() }
        // Only ever live while this screen is on top, so the camera indicator is never lit
        // somewhere else in the app.
        .task { await viewModel.startBoothIfEnabled() }
        .onDisappear { viewModel.onDisappear() }
        .animation(.easeInOut(duration: 0.2), value: booth.isEnabled)
        .onChange(of: session.currentLineIndex) { _, _ in
            viewModel.lineDidChange()
        }
        .onChange(of: session.isPreviewingReference) { _, isPreviewing in
            viewModel.previewDidChange(isPreviewing: isPreviewing)
        }
        .onChange(of: viewModel.recordingAnchor) { _, anchor in
            viewModel.recordingAnchorDidChange(anchor)
        }
        .onChange(of: viewModel.isRecording) { _, isRecording in
            viewModel.recordingDidChange(isRecording: isRecording)
        }
    }

    // MARK: - HUD

    /// Camera-report strip: what is armed, which line, how far through the scene.
    private func hud(for line: DubLine) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    viewModel.stop()
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

                HStack(spacing: 7) {
                    EditorRecordDot(isActive: viewModel.isRecording)
                    Text(viewModel.isRecording ? Strings.Main.State.recording : Strings.Main.State.idle)
                        .editorLabelStyle(viewModel.isRecording ? .rsRecord : .rsTextTertiary)
                }

                Spacer()

                boothKey

                Text(String(format: "%03d / %03d", line.index, session.pack.lines.count))
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextSecondary)
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.top, 10)
            .padding(.bottom, 9)

            DubProgressBar(
                recorded: session.recordedCount,
                total: session.pack.lines.count
            )
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.bottom, 10)
        }
        .background(Color.rsSurface1)
        .overlay(alignment: .bottom) { EditorRule() }
    }

    /// Turns the camera on and off without leaving the take.
    ///
    /// Disabled mid-take: a clip is being written against a deadline that has already been
    /// scheduled, and stopping the camera halfway would leave a fragment of a line that
    /// nothing downstream expects. The choice waits the couple of seconds until the line ends.
    private var boothKey: some View {
        Button {
            HapticManager.shared.light()
            // Reaching for the key is the tip's whole point made.
            boothTip.invalidate(reason: .actionPerformed)
            viewModel.toggleBooth()
        } label: {
            Image(systemName: booth.isEnabled ? "video.fill" : "video.slash.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(booth.isEnabled ? .rsTextPrimary : .rsTextTertiary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.rsSurface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(
                            booth.isEnabled ? Color.rsStrokeStrong : Color.rsStroke,
                            lineWidth: EditorMetrics.hairline
                        )
                )
                .overlay(alignment: .topTrailing) {
                    // The one place the record colour appears outside the transport: the
                    // camera is rolling, and that is worth seeing from the corner of an eye.
                    if viewModel.booth.isWriting {
                        Circle()
                            .fill(Color.rsRecord)
                            .frame(width: 7, height: 7)
                            .overlay(
                                Circle().strokeBorder(Color.rsSurface1, lineWidth: 1.5)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .disabled(viewModel.isRecording)
        .opacity(viewModel.isRecording ? 0.4 : 1)
        .accessibilityLabel(booth.isEnabled ? Strings.Booth.turnOff : Strings.Booth.turnOn)
        .popoverTip(boothTip, arrowEdge: .top)
    }

    // MARK: - Picture

    private func picture(for line: DubLine) -> some View {
        DubPicture(
            player: viewModel.scenePicture.player,
            stillURL: session.pack.imageURL(for: line)
        )
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .id(viewModel.scenePicture.player == nil ? line.slug : "video")
            .cinemaVignette()
            .filmGrain(opacity: 0.06)
            .overlay(alignment: .topLeading) {
                DubCharacterPlate(character: line.character, color: characterColor(for: line))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.rsSurface0.opacity(0.72))
                    .overlay(
                        Rectangle().strokeBorder(
                            characterColor(for: line).opacity(0.45),
                            lineWidth: EditorMetrics.hairline
                        )
                    )
                    .padding(12)
            }
            // Bottom right, nearest the subtitle plate the performer is reading, so checking
            // yourself costs no eyeline. Nothing else on the screen moves to make room.
            .overlay(alignment: .bottomTrailing) {
                if booth.isEnabled, viewModel.booth.isUsable {
                    BoothMonitor(
                        recorder: viewModel.booth,
                        level: viewModel.recordingLevel,
                        isRecording: viewModel.isRecording,
                        playbackURL: session.boothPlaybackURL
                    )
                    .padding(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomTrailing)))
                }
            }
    }

    // MARK: - Waveform Bay

    /// The reference line's shape, with the user's take laid over it. Both are drawn on the
    /// reference's time axis and both run the length of the line, so what the overlay shows is
    /// delivery. Where the performer came in, where they rushed, where they left a gap.
    private func waveformBay(for line: DubLine) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(Strings.Dub.referenceTrack)
                    .editorLabelStyle(.rsTextTertiary)

                if viewModel.isRecording || !viewModel.takeSamples.isEmpty {
                    Text(Strings.Dub.yourTake)
                        .editorLabelStyle(.rsRecord)
                }

                Spacer(minLength: 0)
            }

            DubWaveformView(
                samples: viewModel.referenceSamples,
                overlay: viewModel.takeOverlay,
                overlayTint: .rsRecord,
                progress: viewModel.waveformProgress(for: line),
                height: 52,
                onTap: {
                    HapticManager.shared.impact(.light)
                    viewModel.toggleReferencePreview()
                }
            )
        }
        .padding(.horizontal, EditorMetrics.gutter)
        .padding(.vertical, 12)
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    // MARK: - Subtitle Plate

    /// The line to perform, set like a burned-in subtitle over a dark plate.
    private func subtitlePlate(for line: DubLine) -> some View {
        VStack(spacing: 10) {
            // The performer is looking here, not at the corner of the picture, so this is the
            // copy of the name that has to be unmissable.
            DubCharacterPlate(
                character: line.character,
                color: characterColor(for: line),
                isProminent: true
            )

            Text(line.caption)
                .font(.rsBodyLarge)
                .foregroundColor(.rsTextPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)

            // Pacing: fills across the original line's length
            ZStack(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.rsSurface3)
                        .frame(height: 2)

                    Rectangle()
                        .fill(pacingColor(for: line))
                        .frame(width: geometry.size.width * viewModel.pacingFraction(for: line), height: 2)
                }
                .frame(height: 2)
            }
            .frame(height: 2)
            .padding(.horizontal, 20)
            .opacity(viewModel.isRecording ? 1 : 0.35)

            HStack {
                Text(viewModel.isRecording ? Strings.Dub.recordingHint : Strings.Dub.listenHint)
                    .font(.rsCaptionSmall)
                    .foregroundColor(.rsTextTertiary)

                Spacer()

                Text(viewModel.timerText(for: line))
                    .font(.rsTimecodeSmall)
                    .foregroundColor(viewModel.isOverLength(line) ? .rsCaution : .rsTextSecondary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    private func characterColor(for line: DubLine) -> Color {
        DubCharacterStyle.color(for: line.character, in: session.pack.characters)
    }

    private func pacingColor(for line: DubLine) -> Color {
        viewModel.isOverLength(line) ? .rsCaution : .rsRecord
    }

    // MARK: - Score Bay

    @ViewBuilder
    private var scoreBay: some View {
        if viewModel.showsScoreCard, let score = session.latestScore {
            DubTakeScoreCard(score: score)
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Transport

    private func transportBar(for line: DubLine) -> some View {
        HStack(spacing: 0) {
            transportButton(
                icon: "chevron.left",
                label: Strings.Dub.previous,
                isEnabled: viewModel.canGoToPreviousLine,
                action: viewModel.goToPreviousLine
            )

            transportButton(
                icon: session.isPreviewingReference ? "stop.fill" : "speaker.wave.2.fill",
                label: Strings.Dub.listen,
                isEnabled: !viewModel.isRecording,
                action: viewModel.toggleReferencePreview
            )

            recordButton

            transportButton(
                icon: "play.fill",
                label: Strings.Dub.playTake,
                isEnabled: viewModel.canPlayTake(of: line),
                action: viewModel.playCurrentTake
            )

            // On the last line there is nowhere to go next, and a permanently greyed chevron
            // is a dead end where the session actually ends. It becomes the way out instead.
            if viewModel.isOnLastLine {
                transportButton(
                    icon: "checkmark",
                    label: Strings.Dub.finish,
                    isEnabled: !viewModel.isRecording,
                    action: {
                        viewModel.stop()
                        dismiss()
                    }
                )
            } else {
                transportButton(
                    icon: "chevron.right",
                    label: Strings.Dub.next,
                    isEnabled: !viewModel.isRecording,
                    action: viewModel.goToNextLine
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    /// The one saturated control on the screen, and the only round one, so the
    /// thumb finds it without looking.
    private var recordButton: some View {
        Button {
            recordTip.invalidate(reason: .actionPerformed)
            viewModel.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.rsRecord.opacity(viewModel.isRecording ? 0.18 : 0))
                    .frame(width: 66, height: 66)
                    .scaleEffect(1 + CGFloat(viewModel.recordingLevel) * 0.25)

                RoundedRectangle(
                    cornerRadius: viewModel.isRecording ? 5 : 27,
                    style: .continuous
                )
                .fill(Color.rsRecord)
                .frame(
                    width: viewModel.isRecording ? 26 : 54,
                    height: viewModel.isRecording ? 26 : 54
                )

                Circle()
                    .strokeBorder(Color.rsRecord.opacity(0.5), lineWidth: EditorMetrics.hairline)
                    .frame(width: 66, height: 66)
            }
            .frame(maxWidth: .infinity)
        }
        .animation(.easeOut(duration: 0.12), value: viewModel.recordingLevel)
        .accessibilityLabel(viewModel.isRecording ? Strings.Dub.stop : Strings.Dub.recordTake)
        .popoverTip(recordTip, arrowEdge: .bottom)
    }

    private func transportButton(
        icon: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.rsTextSecondary)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.rsSurface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
                )
                .frame(maxWidth: .infinity)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}
