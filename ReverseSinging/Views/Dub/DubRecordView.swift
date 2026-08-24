//
//  DubRecordView.swift
//  ReverseSinging
//
//  Line-by-line dubbing, laid out like a recording bay: HUD above the
//  picture, subtitle plate below it, transport along the bottom.
//

import SwiftUI

struct DubRecordView: View {
    @ObservedObject var viewModel: DubViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var scenePicture = DubScenePicture()

    var body: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()

            if let line = viewModel.currentLine {
                VStack(spacing: 0) {
                    hud(for: line)

                    picture(for: line)

                    waveformBay(for: line)

                    subtitlePlate(for: line)

                    transportBar(for: line)
                }
            }

            CountdownOverlay(value: viewModel.countdown)
        }
        .statusBarHidden()
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentLineIndex)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
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
        .onAppear {
            scenePicture.configure(with: viewModel.pack)
            if let line = viewModel.currentLine { scenePicture.show(line) }
            AnalyticsManager.shared.trackScreenViewed(screenName: "DubRecord")
        }
        .onDisappear {
            scenePicture.tearDown()
            viewModel.stopEverything()
        }
        // Park the picture on whichever line is up next.
        .onChange(of: viewModel.currentLineIndex) { _, _ in
            guard let line = viewModel.currentLine else { return }
            scenePicture.show(line)
        }
        // Roll the picture whenever the line is being heard or performed, so the user is
        // always dubbing to something rather than to a frozen frame.
        .onChange(of: viewModel.isPreviewingReference) { _, isPreviewing in
            guard let line = viewModel.currentLine else { return }
            isPreviewing ? scenePicture.play(line) : scenePicture.stop(returningTo: line)
        }
        // The take now ends when the line does, so the picture plays it through once and the
        // recording stops on the same frame. Looping is kept for a line of unknown length,
        // where nothing stops the take and a frozen frame would read as broken.
        .onChange(of: viewModel.isRecording) { _, isRecording in
            guard let line = viewModel.currentLine else { return }
            isRecording
                ? scenePicture.play(line, loop: line.duration <= 0)
                : scenePicture.stop(returningTo: line)
        }
    }

    // MARK: - HUD

    /// Camera-report strip: what is armed, which line, how far through the scene.
    private func hud(for line: DubLine) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    viewModel.stopEverything()
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

                Text(String(format: "%03d / %03d", line.index, viewModel.pack.lines.count))
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextSecondary)
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.top, 10)
            .padding(.bottom, 9)

            DubProgressBar(
                recorded: viewModel.recordedCount,
                total: viewModel.pack.lines.count
            )
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.bottom, 10)
        }
        .background(Color.rsSurface1)
        .overlay(alignment: .bottom) { EditorRule() }
    }

    // MARK: - Picture

    private func picture(for line: DubLine) -> some View {
        DubPicture(
            player: scenePicture.player,
            stillURL: viewModel.pack.imageURL(for: line)
        )
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .id(scenePicture.player == nil ? line.slug : "video")
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
    }

    // MARK: - Waveform Bay

    /// The reference line's shape, with the user's take laid over it. Both are drawn on the
    /// reference's time axis and both run the length of the line, so what the overlay shows is
    /// delivery — where the performer came in, where they rushed, where they left a gap.
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
                overlay: takeOverlay,
                overlayTint: .rsRecord,
                progress: waveformProgress(for: line),
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

    /// While the mic is open this is the live trace; once a take exists it is that take's
    /// real shape, so the comparison survives past the end of the recording.
    ///
    /// Both fill the rail, because a take is always the length of the line it replaces.
    private var takeOverlay: [Float]? {
        if viewModel.isRecording {
            return viewModel.liveTrace.isEmpty ? nil : viewModel.liveTrace
        }
        return viewModel.takeSamples.isEmpty ? nil : viewModel.takeSamples
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
                        .frame(width: geometry.size.width * pacingFraction(for: line), height: 2)
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

                Text(timerText(for: line))
                    .font(.rsTimecodeSmall)
                    .foregroundColor(overLength(line) ? .rsCaution : .rsTextSecondary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    /// The playhead: where the preview has got to, or — while the mic is open — where the take
    /// has. During a take it is the only thing on screen that says *where in the line you are*,
    /// which is what lets a performer see the original's run-up coming rather than talking
    /// straight over it.
    private func waveformProgress(for line: DubLine) -> Double? {
        if viewModel.isRecording {
            guard line.duration > 0 else { return nil }
            return min(1, viewModel.recordingDuration / line.duration)
        }
        return viewModel.isPreviewingReference ? viewModel.previewProgress : nil
    }

    private func characterColor(for line: DubLine) -> Color {
        DubCharacterStyle.color(for: line.character, in: viewModel.pack.characters)
    }

    private func pacingFraction(for line: DubLine) -> Double {
        guard viewModel.isRecording, line.duration > 0 else { return 0 }
        return min(1.0, viewModel.recordingDuration / line.duration)
    }

    private func overLength(_ line: DubLine) -> Bool {
        viewModel.isRecording && line.duration > 0 && viewModel.recordingDuration > line.duration
    }

    private func pacingColor(for line: DubLine) -> Color {
        overLength(line) ? .rsCaution : .rsRecord
    }

    private func timerText(for line: DubLine) -> String {
        let elapsed = viewModel.isRecording ? viewModel.recordingDuration : 0
        return String(format: "%05.2f / %05.2f", elapsed, line.duration)
    }

    // MARK: - Transport

    private func transportBar(for line: DubLine) -> some View {
        HStack(spacing: 0) {
            transportButton(
                icon: "chevron.left",
                label: Strings.Dub.previous,
                isEnabled: viewModel.currentLineIndex > 0 && !viewModel.isRecording,
                action: viewModel.goToPreviousLine
            )

            transportButton(
                icon: viewModel.isPreviewingReference ? "stop.fill" : "speaker.wave.2.fill",
                label: Strings.Dub.listen,
                isEnabled: !viewModel.isRecording,
                action: viewModel.toggleReferencePreview
            )

            recordButton

            transportButton(
                icon: "play.fill",
                label: Strings.Dub.playTake,
                isEnabled: viewModel.isRecorded(line) && !viewModel.isRecording,
                action: viewModel.playCurrentTake
            )

            transportButton(
                icon: "chevron.right",
                label: Strings.Dub.next,
                isEnabled: viewModel.currentLineIndex < viewModel.pack.lines.count - 1 && !viewModel.isRecording,
                action: viewModel.goToNextLine
            )
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    /// The one saturated control on the screen, and the only round one — so the
    /// thumb finds it without looking.
    private var recordButton: some View {
        Button {
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
