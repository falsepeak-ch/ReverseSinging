//
//  MainViewPremium.swift
//  ReverseSinging
//
//  Premium redesigned main view
//

import SwiftUI

struct MainViewPremium: View {
    @EnvironmentObject var viewModel: AudioViewModel
    @State private var showSuccessToast = false
    @State private var showCelebration = false
    @State private var showNewSessionAlert = false
    @State private var isScoreVisible = true
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

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
                // Scrollable content layer
                mainContentView
            }

            // Fixed header overlay (always visible)
            ReverseGameHeader(viewModel: viewModel, onBack: { dismiss() })

            // Overlays (processing, toasts, etc.)
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
        .reverseGameChrome(viewModel: viewModel, screenName: "MainView")
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top spacer for fixed header
                Color.clear
                    .frame(height: 100)

                // Waveform visualization (hidden when playing)
                if shouldShowWaveform {
                    waveformCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .animatedCard(delay: 0.1)
                        .transition(.opacity.combined(with: .scale))
                }

                // Timer card (prominent when recording/playing)
                if shouldShowTimer {
                    timerCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }

                // Action buttons
                actionButtonsSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                    .animation(.rsSpring, value: viewModel.appState.recordingState)
            }
        }
    }

    // MARK: - Overlays

    private var overlaysView: some View {
        ZStack {
            // Success toast overlay
            if showSuccessToast {
                VStack {
                    SuccessToast(message: Strings.Main.successSessionSaved, isPresented: $showSuccessToast)
                        .padding(.horizontal, 24)
                        .padding(.top, 120)
                    Spacer()
                }
            }

            // Celebration overlay
            if showCelebration {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showCelebration = false
                            }
                        }

                    SuccessCelebration()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showCelebration = false
                                }
                            }
                        }
                }
            }

            // Processing indicator overlay
            if viewModel.isReversing {
                ProcessingIndicator(message: Strings.Main.processingReversingAudio)
                    .transition(.scale.combined(with: .opacity))
            }

            // Tip overlay at bottom (only shown when permission is granted)
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

    // MARK: - Waveform

    private var waveformCard: some View {
        VStack(spacing: 0) {
            // Recording status indicator (top of card)
            if case .recording = viewModel.appState.recordingState {
                HStack {
                    RecordingIndicator()
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Waveform
            WaveformView(
                level: viewModel.recordingLevel,
                barCount: 80,
                style: waveformStyle,
                recordingDuration: isCurrentlyRecording ? viewModel.recordingDuration : nil
            )
            .frame(height: 140)
            .padding(.horizontal, 20)
            .padding(.vertical, waveformPadding)
        }
        .background(waveformCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(waveformBorderColor, lineWidth: 1)
        )
        .cardShadow(.card)
    }

    private var waveformCardBackground: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.85)      // Dark translucent in dark mode
            : Color.white.opacity(0.95)      // Light translucent in light mode
    }

    private var waveformBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)   // Lighter border in dark mode
            : Color.black.opacity(0.15)   // Darker border in light mode
    }

    private var waveformPadding: CGFloat {
        switch viewModel.appState.recordingState {
        case .recording:
            return 16
        default:
            return 24
        }
    }

    private var waveformStyle: WaveformView.WaveformStyle {
        switch viewModel.appState.recordingState {
        case .recording:
            return .recording
        case .playing:
            return .playing
        default:
            return .idle
        }
    }

    // MARK: - Dynamic Tip Text

    private var currentTip: String? {
        guard let session = viewModel.appState.currentSession else {
            return Strings.Main.Tip.tapRecordToBegin
        }

        // Show tips during recording
        if case .recording = viewModel.appState.recordingState {
            if session.attemptRecording != nil {
                // Re-recording attempt
                return Strings.Main.Tip.recordSingingAttempt
            } else if session.reversedRecording != nil {
                // Recording attempt for first time
                return Strings.Main.Tip.recordSingingAttempt
            } else {
                // Recording original
                return Strings.Main.Tip.recordSongToReverse
            }
        }

        // Show tips during playback
        if case .playing = viewModel.appState.recordingState {
            return Strings.Main.Tip.tapPlayToSwitch
        }

        // Step-based tips for idle states
        if session.attemptRecording != nil {
            return Strings.Main.Tip.reRecordOrNewSession
        } else if session.reversedRecording != nil {
            return Strings.Main.Tip.listenAndRecord
        } else if session.originalRecording != nil {
            // Original recording exists but not reversed yet - processing
            return Strings.Main.Tip.processingAudio
        } else {
            // Initial state - no recordings yet
            return Strings.Main.Tip.tapRecordAudio
        }
    }

    // MARK: - Waveform

    private var shouldShowWaveform: Bool {
        // Always show waveform when recording (any type)
        if case .recording = viewModel.appState.recordingState {
            return true
        }

        // Hide when playing
        if case .playing = viewModel.appState.recordingState {
            return false
        }

        // Hide after original recording exists (when idle/not recording)
        if viewModel.appState.currentSession?.originalRecording != nil {
            return false
        }

        // Show in all other idle cases (before any recording)
        return true
    }

    // MARK: - Timer Card

    private var shouldShowTimer: Bool {
        // Hide timer during recording (it's shown in waveform instead)
        if case .recording = viewModel.appState.recordingState {
            return false
        }

        // Show when playing OR when any audio exists (idle after recording)
        if case .playing = viewModel.appState.recordingState {
            return true
        }

        // Show when playable audio exists and idle
        guard let session = viewModel.appState.currentSession else { return false }
        return session.reversedRecording != nil ||
               session.attemptRecording != nil ||
               session.reversedAttempt != nil
    }

    private var timerCard: some View {
        let session = viewModel.appState.currentSession

        return TimerCard(
            duration: timerDuration,
            deviceName: nil,
            isRecording: isCurrentlyRecording,
            state: timerState,
            onPlayOriginal: {
                if let original = session?.originalRecording {
                    viewModel.playRecording(original)
                }
            },
            onPlayReversed: {
                if let reversed = session?.reversedRecording {
                    viewModel.playRecording(reversed)
                }
            },
            onPlayAttempt: {
                if let attempt = session?.attemptRecording {
                    viewModel.playRecording(attempt)
                }
            },
            onPlayReversedAttempt: {
                if let reversedAttempt = session?.reversedAttempt {
                    viewModel.playRecording(reversedAttempt)
                }
            },
            hasOriginal: session?.originalRecording != nil,
            hasReversed: session?.reversedRecording != nil,
            hasAttempt: session?.attemptRecording != nil,
            hasReversedAttempt: session?.reversedAttempt != nil,
            onStopPlayback: { viewModel.stopPlayback() },
            playbackSpeed: Binding(
                get: { viewModel.appState.playbackSpeed },
                set: { _ in }
            ),
            isLooping: Binding(
                get: { viewModel.appState.isLooping },
                set: { _ in }
            ),
            pitchShift: Binding(
                get: { viewModel.appState.pitchShift },
                set: { _ in }
            ),
            onSpeedChange: { speed in
                viewModel.setPlaybackSpeed(speed)
            },
            onLoopToggle: {
                viewModel.toggleLooping()
            },
            onPitchChange: { pitch in
                viewModel.setPitchShift(pitch)
            }
        )
    }

    private var isCurrentlyRecording: Bool {
        if case .recording = viewModel.appState.recordingState {
            return true
        }
        return false
    }

    private var timerDuration: TimeInterval {
        switch viewModel.appState.recordingState {
        case .playing:
            return viewModel.playbackProgress
        case .recording:
            // Recording time shown in waveform, not here
            return 0
        default:
            // Show 00:00 when idle (user preference)
            return 0
        }
    }

    private var timerState: TimerCard.TimerState {
        switch viewModel.appState.recordingState {
        case .idle:
            return .idle
        case .recording:
            return .recording
        case .playing:
            return .playing
        case .reversing:
            return .processing
        default:
            return .idle
        }
    }


    // MARK: - Playback Controls
    // Playback controls are now integrated into TimerCard

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            let session = viewModel.appState.currentSession
            let isRecording = viewModel.appState.recordingState == .recording
            let isPlaying = viewModel.appState.recordingState == .playing

            // Button 1: Record Audio (only shown when no original recording exists)
            if session?.originalRecording == nil {
                BigButton(
                    title: isRecording ? Strings.Main.stopRecording : Strings.Main.recordAudio,
                    icon: isRecording ? "stop.circle.fill" : "mic.fill",
                    color: .rsRecording,
                    action: {
                        if isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    },
                    style: .primary
                )
            }

            // Record Your Attempt (only shown when reversed exists and no attempt yet, hidden when playing)
            if session?.reversedRecording != nil && session?.attemptRecording == nil && !isPlaying {
                BigButton(
                    title: isRecording ? Strings.Main.stopRecording : Strings.Main.recordAttempt,
                    icon: isRecording ? "stop.circle.fill" : "mic.fill",
                    color: .rsRecording,
                    action: {
                        if isRecording {
                            viewModel.stopRecording(type: .attempt)
                        } else {
                            viewModel.startRecording()
                        }
                    },
                    style: .primary
                )
            }

            // ScoreCard (shown when score is available)
            if let score = viewModel.appState.similarityScore, !isRecording {
                ScoreCard(score: score, isVisible: $isScoreVisible)
                    .frame(maxWidth: .infinity)
            }

            // Bottom buttons: Re-record and Start New Session
            HStack(spacing: 12) {
                if session?.attemptRecording != nil && !isRecording {
                    BigButton(
                        title: Strings.Main.reRecord,
                        icon: "record.circle",
                        color: .rsRecording,
                        action: {
                            viewModel.reRecordAttempt()
                            viewModel.startRecording()
                        },
                        style: .secondary
                    )
                }

                // Only show New Session if there are recordings in current session
                if session != nil && !session!.recordings.isEmpty {
                    BigButton(
                        title: Strings.Main.newSession,
                        icon: "plus.circle.fill",
                        color: .rsTurquoise,
                        action: { showNewSessionAlert = true },
                        style: .secondary
                    )
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Preview

#Preview {
    MainViewPremium()
        .environmentObject(AudioViewModel())
}
