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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Where the window's middle falls across the bay (see `readWindowMiddleRatio`).
    @State private var seamRatio: CGFloat = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var bayNamespace

    /// The first-run coaching, one at a time. See `DubTips`.
    private let recordTip = DubRecordTip()
    private let boothTip = DubBoothTip()

    init(session: DubSessionViewModel) {
        self.session = session
        _viewModel = StateObject(wrappedValue: DubRecordViewModel(session: session))
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone Duo open: the booth keeps the system's strip (status and a standard Close),
    /// its content inside the safe area beside it. Elsewhere the booth is the whole screen
    /// with its own close key, as it always was.
    private var usesSystemBar: Bool {
        EditorBars.useSystemBar(horizontalSizeClass, verticalSizeClass)
    }

    private func close() {
        viewModel.stop()
        dismiss()
    }

    var body: some View {
        #if os(iOS)
        if usesSystemBar {
            NavigationStack {
                bayScreen
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: close) {
                                Label(Strings.Help.close, systemImage: "xmark")
                            }
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationBarTitleDisplayMode(.inline)
            }
        } else {
            bayScreen.hidesStatusBar()
        }
        #else
        bayScreen.hidesStatusBar()
        #endif
    }

    private var bayScreen: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()

            if let line = session.currentLine {
                bay(for: line)
            }

            CountdownOverlay(value: viewModel.countdown)
        }
        // Opening or closing the device swaps the layout; the take, line and recording
        // state live in the view models, so only the geometry changes.
        .animation(reduceMotion ? nil : .rsSmooth, value: horizontalSizeClass)
        .animation(.easeInOut(duration: 0.2), value: session.currentLineIndex)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
        .animation(.rsSpring, value: session.latestScore)
        .microphonePrimer()
        .takePaywall(isPresented: $viewModel.isTakePaywallPresented, kind: .dub)
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: $viewModel.showPermissionAlert) {
            Button(Strings.Main.Alert.settings, action: AppSettings.open)
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

    // MARK: - Bay

    /// The booth as two panes: the scene (HUD and picture) and the desk (waveform, line,
    /// score, transport). On a regular width with iOS 27.1 a split arrangement holds them:
    /// - fully open and wider than tall, a studio: the picture large, the desk beside it;
    /// - taller than wide, or half folded as a table, the picture above and the desk below,
    ///   with equal halves so the fold falls between the panes, never through the picture.
    /// The system places the panes around the fold. Compact widths, older systems and the
    /// Mac keep the single column.
    @ViewBuilder
    private func bay(for line: DubLine) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *), horizontalSizeClass == .regular {
            ArrangementView {
                screen(for: line)
                    .splitArrangementLayoutRatio(idealHorizontal: pictureRatio, idealVertical: 0.5)
            } secondary: {
                SplitAxisReader { axis in
                    controls(for: line, isBeside: axis == .horizontal)
                }
            }
            .arrangementViewStyle(.split)
            .readWindowMiddleRatio(into: $seamRatio)
        } else {
            stackedBay(for: line)
        }
        #else
        stackedBay(for: line)
        #endif
    }

    /// The picture's share beside the desk: most of an iPad, but on iPhone Duo open flat
    /// exactly up to the seam, so the picture never runs across the middle of the display.
    private var pictureRatio: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone { return seamRatio }
        #endif
        return 0.62
    }

    private func stackedBay(for line: DubLine) -> some View {
        VStack(spacing: 0) {
            screen(for: line)
            controls(for: line, isBeside: false)
        }
    }

    private func screen(for line: DubLine) -> some View {
        VStack(spacing: 0) {
            hud(for: line)
            picture(for: line)
                // The same picture in every layout, so a pose change moves and resizes it
                // rather than cutting to a new one.
                .matchedGeometryEffect(id: "picture", in: bayNamespace)
        }
    }

    /// Beside the picture the desk is a full-height column: the waveform at the top, the
    /// line to read in the middle at eye level, the transport at the bottom in reach.
    private func controls(for line: DubLine, isBeside: Bool) -> some View {
        VStack(spacing: 0) {
            waveformBay(for: line)
            if isBeside {
                Spacer(minLength: 0)
            }
            subtitlePlate(for: line)
            if isBeside {
                Spacer(minLength: 0)
            }
            scoreBay
            transportBar(for: line)
        }
        .background(isBeside ? Color.rsSurface1 : Color.clear)
        .overlay(alignment: .leading) {
            if isBeside {
                Rectangle()
                    .fill(Color.rsStroke)
                    .frame(width: EditorMetrics.hairline)
            }
        }
    }

    // MARK: - HUD

    /// Camera-report strip: what is armed, which line, how far through the scene.
    private func hud(for line: DubLine) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // The system bar's Close where there is one (`usesSystemBar`).
                if !usesSystemBar {
                Button {
                    close()
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
            // The vignette ignores safe areas; keep it inside the picture's own pane.
            .clipped()
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
            .macKeyboardShortcut(.leftArrow)

            transportButton(
                icon: session.isPreviewingReference ? "stop.fill" : "speaker.wave.2.fill",
                label: Strings.Dub.listen,
                isEnabled: !viewModel.isRecording,
                action: viewModel.toggleReferencePreview
            )
            .macKeyboardShortcut("l")

            recordButton
                .macKeyboardShortcut(.space)

            transportButton(
                icon: "play.fill",
                label: Strings.Dub.playTake,
                isEnabled: viewModel.canPlayTake(of: line),
                action: viewModel.playCurrentTake
            )
            .macKeyboardShortcut("p")

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
                .macKeyboardShortcut(.rightArrow)
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

#if os(iOS)
/// Hands its content the axis the enclosing split arrangement chose, so a pane can lay
/// itself out for beside or below.
@available(iOS 27.1, *)
private struct SplitAxisReader<Content: View>: View {
    @Environment(\.splitArrangementAxis) private var axis
    @ViewBuilder let content: (Axis?) -> Content

    var body: some View { content(axis) }
}
#endif

#Preview("iPhone") {
    DubRecordView(session: DubSessionViewModel(pack: .previewLicensed))
        .cinemaAppearance()
}

#Preview("Duo open, landscape (studio)", traits: .fixedLayout(width: 1427, height: 1003)) {
    DubRecordView(session: DubSessionViewModel(pack: .previewLicensed))
        .cinemaAppearance()
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .regular)
}

#Preview("Duo open, portrait", traits: .fixedLayout(width: 1003, height: 1427)) {
    DubRecordView(session: DubSessionViewModel(pack: .previewLicensed))
        .cinemaAppearance()
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .regular)
}
