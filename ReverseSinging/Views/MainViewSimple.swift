//
//  MainViewSimple.swift
//  ReverseSinging
//
//  Simple UI with three large buttons
//

import SwiftUI

struct MainViewSimple: View {
    @EnvironmentObject var viewModel: AudioViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showNewSessionAlert = false

    var body: some View {

        ZStack {
            // Background color layer
            Color.rsBackgroundAdaptive(for: colorScheme)
                .ignoresSafeArea()

            // Show empty state if permission is denied
            if !viewModel.hasRecordingPermission {
                MicrophonePermissionEmptyState(onOpenSettings: AppSettings.open)
                    .transition(.opacity)
            } else {
                // Main content
                mainContentView
            }

            // Fixed header overlay (always visible)
            ReverseGameHeader(viewModel: viewModel, onBack: { dismiss() })

            // Overlays (processing, tips, etc.)
            overlaysView

            CountdownOverlay(value: viewModel.countdown)
        }
        .alert(Strings.Main.Alert.startNewSessionTitle, isPresented: $showNewSessionAlert) {
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
            Button(Strings.Main.Alert.startNewSessionButton, role: .destructive) {
                viewModel.startNewSession()
            }
        } message: {
            Text(Strings.Main.Alert.startNewSessionMessage)
        }
        .reverseGameChrome(viewModel: viewModel, screenName: "MainViewSimple")
    }

    // MARK: - Main Content

    /// Spacers distribute the stack on a tall screen; on a short one the same
    /// content scrolls instead of being squeezed, which is what `minHeight` buys.
    private var mainContentView: some View {
        GeometryReader { proxy in
            ScrollView {
                transportStack
                    .frame(minHeight: proxy.size.height)
            }
        }
    }

    private var transportStack: some View {
        VStack(spacing: 0) {
            // Clears the fixed header bar
            Spacer().frame(height: 96)

            monitorPanel
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.top, 20)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 10) {
                EditorSectionHeader(title: Strings.Main.Section.transport)
                threeButtonStack
            }
            .padding(.horizontal, EditorMetrics.gutter)

            // The tips tell the user to start a new session once a take exists, so the
            // control has to be here too — not only in the premium skin.
            if hasRecordings {
                VStack(alignment: .leading, spacing: 10) {
                    EditorSectionHeader(title: Strings.Main.Section.session)
                    BigButton(
                        title: Strings.Main.newSession,
                        icon: "plus.circle.fill",
                        color: .rsTurquoise,
                        action: { showNewSessionAlert = true },
                        isEnabled: !isRecording,
                        style: .secondary
                    )
                }
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.top, 20)
            }

            Spacer(minLength: 16)

            Color.clear.frame(height: 88)
        }
    }

    // MARK: - Monitor

    /// The always-present readout: transport state, big timecode, and a level rail.
    /// An editor never shows an empty stage, so this stands in for the program monitor.
    private var monitorPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                EditorRecordDot(isActive: isRecording)

                Text(transportState)
                    .editorLabelStyle(isRecording ? .rsRecord : .rsTextTertiary)

                Spacer()

                Text(takeLabel)
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            EditorRule()

            VStack(spacing: 14) {
                Text(displayDuration.rsClockHundredths)
                    .font(.rsTimecodeLarge)
                    .foregroundColor(isRecording ? .rsRecord : .rsTextPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.15), value: displayDuration)

                LevelRail(level: CGFloat(viewModel.recordingLevel), isActive: isRecording)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
        .editorPanel()
    }

    private var transportState: String {
        switch viewModel.appState.recordingState {
        case .recording: return Strings.Main.State.recording
        case .playing: return Strings.Main.State.playing
        case .reversing: return Strings.Main.State.processing
        case .error: return Strings.Main.State.error
        case .idle: return Strings.Main.State.idle
        }
    }

    private var takeLabel: String {
        let attempts = viewModel.appState.attemptCount
        return attempts > 0 ? String(format: "TAKE %02d", attempts + 1) : "TAKE 01"
    }

    // MARK: - Three Button Stack

    private var threeButtonStack: some View {
        VStack(spacing: 8) {
            // Button 1: Record Audio / Stop Recording (Red)
            // Dynamic button that changes based on recording state
            LargeActionButton(
                title: isRecording ? Strings.Main.stopRecording : Strings.Main.recordAudio,
                subtitle: subtitleForRecordButton,
                icon: isRecording ? "stop.circle.fill" : "mic.fill",
                dotCount: isRecording ? 3 : 0,
                color: .rsRecording,
                isEnabled: canRecord || isRecording,
                recordingLevel: viewModel.recordingLevel,
                action: handleRecordToggle
            )

            // Button 2: Play Recorded (Green)
            LargeActionButton(
                title: Strings.Main.playRecorded,
                subtitle: subtitleForPlayButton,
                icon: "play.circle.fill",
                dotCount: 0,
                color: .rsSuccess,
                isEnabled: canPlayOriginal,
                recordingLevel: 0,
                action: handlePlayOriginal
            )

            // Button 3: Play Reverse (Blue)
            LargeActionButton(
                title: Strings.Main.playReverse,
                subtitle: subtitleForReverseButton,
                icon: "arrow.triangle.2.circlepath",
                dotCount: 0,
                color: .rsTurquoise,
                isEnabled: canPlayReversed,
                recordingLevel: 0,
                action: handlePlayReversed
            )
        }
    }

    // MARK: - Overlays

    private var overlaysView: some View {
        ZStack {
            if viewModel.isReversing {
                ProcessingIndicator(message: Strings.Main.processingReversingAudio)
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.hasRecordingPermission, let tip = currentTip, !tip.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    HintBar(text: tip)
                        .id(tip)
                        .transition(.opacity)
                }
                .animation(.rsSpring, value: tip)
            }
        }
    }

    // MARK: - Helpers

    private var currentTip: String? {
        let session = viewModel.appState.currentSession
        let state = viewModel.appState.recordingState

        switch state {
        case .recording:
            if session?.originalRecording == nil {
                return Strings.Main.Tip.recordSongToReverse
            } else if session?.attemptRecording == nil {
                return Strings.Main.Tip.recordSingingAttempt
            }
            return nil

        case .playing:
            return Strings.Main.Tip.tapPlayToSwitch

        case .reversing:
            return Strings.Main.Tip.processingAudio

        case .idle:
            if session == nil || session?.originalRecording == nil {
                return Strings.Main.Tip.tapRecordToBegin
            } else if session?.reversedRecording != nil && session?.attemptRecording == nil {
                return Strings.Main.Tip.listenAndRecord
            } else if session?.attemptRecording != nil {
                return Strings.Main.Tip.reRecordOrNewSession
            } else if session?.originalRecording != nil {
                return Strings.Main.Tip.recordSongToReverse
            }
            return nil

        case .error:
            return nil
        }
    }

    private var displayDuration: TimeInterval {
        if viewModel.appState.recordingState == .recording {
            return viewModel.recordingDuration
        } else if viewModel.appState.recordingState == .playing {
            return viewModel.playbackProgress
        }
        return 0
    }

    private var shouldShowTimer: Bool {
        switch viewModel.appState.recordingState {
        case .recording, .playing:
            return true
        case .idle, .reversing, .error:
            return false
        }
    }

    // MARK: - Button States

    private var isRecording: Bool {
        return viewModel.appState.recordingState == .recording
    }

    private var hasRecordings: Bool {
        !(viewModel.appState.currentSession?.recordings.isEmpty ?? true)
    }

    private var canRecord: Bool {
        // Can always record when not already recording
        return viewModel.appState.recordingState != .recording
    }

    private var canPlayOriginal: Bool {
        let session = viewModel.appState.currentSession
        return session?.originalRecording != nil || session?.attemptRecording != nil
    }

    private var canPlayReversed: Bool {
        let session = viewModel.appState.currentSession
        return session?.reversedRecording != nil || session?.reversedAttempt != nil
    }

    // MARK: - Button Subtitles

    private var subtitleForRecordButton: String? {
        if isRecording {
            let session = viewModel.appState.currentSession
            if session?.originalRecording == nil {
                return Strings.Main.Subtitle.recordingOriginal
            } else {
                return Strings.Main.Subtitle.recordingAttempt
            }
        } else {
            let session = viewModel.appState.currentSession
            if session?.originalRecording == nil {
                return Strings.Main.Subtitle.tapToRecord
            } else if session?.attemptRecording == nil {
                return Strings.Main.Subtitle.recordAttempt
            } else {
                return Strings.Main.Subtitle.reRecordAttempt
            }
        }
    }

    private var subtitleForPlayButton: String? {
        let session = viewModel.appState.currentSession
        if session?.attemptRecording != nil {
            return Strings.Main.Subtitle.playAttempt
        } else if session?.originalRecording != nil {
            return Strings.Main.Subtitle.playOriginal
        }
        return Strings.Main.Subtitle.noRecording
    }

    private var subtitleForReverseButton: String? {
        let session = viewModel.appState.currentSession
        if session?.reversedAttempt != nil {
            return Strings.Main.Subtitle.playReversedAttempt
        } else if session?.reversedRecording != nil {
            return Strings.Main.Subtitle.playReversedOriginal
        }
        return Strings.Main.Subtitle.noReversed
    }

    // MARK: - Button Actions

    private func handleRecordToggle() {
        if isRecording {
            // Stop recording
            let session = viewModel.appState.currentSession
            if session?.originalRecording == nil {
                viewModel.stopRecording()
            } else {
                viewModel.stopRecording(type: .attempt)
            }
        } else {
            // A second attempt would otherwise be appended behind the first, which the
            // session still reads as the current take. Clear it first, as premium does.
            if viewModel.appState.currentSession?.attemptRecording != nil {
                viewModel.reRecordAttempt()
            }
            viewModel.startRecording()
        }
    }

    private func handlePlayOriginal() {
        let session = viewModel.appState.currentSession

        if viewModel.appState.recordingState == .playing {
            viewModel.stopPlayback()
        } else {
            if let attempt = session?.attemptRecording {
                viewModel.playRecording(attempt)
            } else if let original = session?.originalRecording {
                viewModel.playRecording(original)
            }
        }
    }

    private func handlePlayReversed() {
        let session = viewModel.appState.currentSession

        if viewModel.appState.recordingState == .playing {
            viewModel.stopPlayback()
        } else {
            if let reversedAttempt = session?.reversedAttempt {
                viewModel.playRecording(reversedAttempt)
            } else if let reversed = session?.reversedRecording {
                viewModel.playRecording(reversed)
            }
        }
    }
}

// MARK: - Large Action Button

/// A transport row: a state bar, an icon well, a label pair and a live meter.
///
/// Replaces the previous full-bleed colour block. Colour survives only in the 3pt
/// leading bar and the meter, which is what keeps a screen of these near-monochrome
/// while still making the armed action unmistakable.
struct LargeActionButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let dotCount: Int          // > 0 shows the live level meter
    let color: Color
    let isEnabled: Bool
    let recordingLevel: Float
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var smoothedLevel: CGFloat = 0

    private var isActive: Bool { dotCount > 0 }

    var body: some View {
        Button(action: {
            if isEnabled {
                HapticManager.shared.impact(.medium)
                action()
            }
        }) {
            HStack(spacing: 0) {
                // State bar. The row's only permanent colour
                Rectangle()
                    .fill(isEnabled ? color : Color.rsStroke)
                    .frame(width: 3)

                HStack(spacing: 14) {
                    iconWell

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.rsButtonMedium)
                            .tracking(0.3)
                            .foregroundColor(.rsTextPrimary)
                            .lineLimit(1)

                        if let subtitle {
                            Text(subtitle)
                                .font(.rsMeta)
                                .foregroundColor(.rsTextTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    if isActive {
                        LevelMeter(level: smoothedLevel, tint: color)
                    } else if isEnabled {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.rsTextTertiary)
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .fill(isActive ? color.opacity(0.10) : Color.rsSurface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .strokeBorder(
                        isActive ? color.opacity(0.5) : Color.rsStroke,
                        lineWidth: EditorMetrics.hairline
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.18), value: isEnabled)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .onChange(of: recordingLevel) { _, level in
            // Momentum smoothing so the meter settles instead of flickering
            smoothedLevel = smoothedLevel * 0.7 + CGFloat(level) * 0.3
        }
    }

    private var iconWell: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(isActive ? color : .rsTextSecondary)
            .frame(width: 40, height: 40)
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

// MARK: - Level Meter

/// Four segments that fill from the bottom, like a channel strip. Reads as a meter
/// at a glance, unlike the pulsing dots it replaces.
struct LevelMeter: View {
    let level: CGFloat
    var tint: Color = .rsRecord
    var barCount: Int = 4

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                let threshold = CGFloat(index + 1) / CGFloat(barCount)
                let isLit = level >= threshold * 0.85

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(isLit ? tint : Color.rsSurface3)
                    .frame(width: 3, height: 8 + CGFloat(index) * 5)
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }
}

#Preview {
    MainViewSimple()
        .environmentObject(AudioViewModel())
}
