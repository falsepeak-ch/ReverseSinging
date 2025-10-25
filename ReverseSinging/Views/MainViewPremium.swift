//
//  MainViewPremium.swift
//  ReverseSinging
//
//  Premium redesigned main view
//

import SwiftUI

struct MainViewPremium: View {
    @StateObject private var viewModel = AudioViewModel()
    @State private var showSuccessToast = false
    @State private var showCelebration = false
    @State private var showComparisonView = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Minimal header
                    headerView
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    // Removed step indicator - simplified to single screen

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

                    // Re-record button and tip (under mini player)
                    if viewModel.appState.currentSession?.attemptRecording != nil && viewModel.appState.recordingState != .recording {
                        VStack(spacing: 12) {
                            // Tip text
                            tipText("Practice makes perfect - record as many attempts as you need")

                            // Small re-record button
                            Button(action: {
                                viewModel.reRecordAttempt()
                                viewModel.startRecording()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "record.circle")
                                        .font(.rsBodyMedium)
                                    Text("Re-record Attempt")
                                        .font(.rsBodySmall)
                                }
                                .foregroundColor(.rsRecording)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.rsRecording.opacity(0.15))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale))
                    }

                    // Removed stage progress - simplified to single screen
                    // Playback controls now integrated into TimerCard

                    // Action buttons
                    actionButtonsSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .animation(.rsSpring, value: viewModel.appState.recordingState)
                }
            }
            .background(Color.rsBackground.ignoresSafeArea())
            .overlay(alignment: .top) {
                if showSuccessToast {
                    SuccessToast(message: "Session saved!", isPresented: $showSuccessToast)
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                }
            }
            .overlay {
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
            }
            .overlay(alignment: .center) {
                if viewModel.isReversing {
                    ProcessingIndicator(message: "Reversing audio...")
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .sheet(isPresented: $viewModel.showSessionList) {
                SessionListView(viewModel: viewModel)
            }
            .sheet(isPresented: $showComparisonView) {
                if let session = viewModel.appState.currentSession,
                   let originalRecording = session.originalRecording,
                   let reversedAttempt = session.reversedAttempt,
                   let score = viewModel.appState.similarityScore {
                    ComparisonView(
                        viewModel: viewModel,
                        originalRecording: originalRecording,
                        reversedAttempt: reversedAttempt,
                        similarityScore: score
                    )
                }
            }
            .alert("Microphone Access Required", isPresented: $viewModel.showPermissionAlert) {
                Button("Settings", action: openSettings)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable microphone access in Settings to record audio.")
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.appState.similarityScore) { oldValue, newValue in
                // Automatically show comparison when score is calculated
                if newValue != nil && oldValue == nil {
                    showComparisonView = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Reverse Singing")
                .font(.rsHeadingMedium)
                .foregroundColor(.rsText)

            Spacer()

            Button(action: { viewModel.showSessionList = true }) {
                Image(systemName: "archivebox")
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsGradientCyan)
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

        // Show when playing
        if case .playing = viewModel.appState.recordingState {
            return true
        }

        // Show when playable audio exists
        guard let session = viewModel.appState.currentSession else { return false }
        return session.reversedRecording != nil ||
               session.attemptRecording != nil ||
               session.reversedAttempt != nil
    }

    private var timerCard: some View {
        TimerCard(
            duration: timerDuration,
            deviceName: nil,
            isRecording: isCurrentlyRecording,
            state: timerState,
            playbackSpeed: Binding(
                get: { viewModel.appState.playbackSpeed },
                set: { viewModel.setPlaybackSpeed($0) }
            ),
            isLooping: Binding(
                get: { viewModel.appState.isLooping },
                set: { _ in viewModel.toggleLooping() }
            ),
            onStopPlayback: { viewModel.stopPlayback() }
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
                    title: isRecording ? "Stop Recording" : "Record Audio",
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

            // 2x2 Grid: All 4 playback buttons (shown after attempt is recorded)
            if session?.attemptRecording != nil && !isRecording && !isPlaying {
                VStack(spacing: 12) {
                    // Row 1: Play Original | Play Reversed
                    HStack(spacing: 12) {
                        BigButton(
                            title: "Play Original",
                            icon: "play.circle.fill",
                            color: .rsGradientCyan,
                            action: {
                                if let original = session?.originalRecording {
                                    viewModel.playRecording(original)
                                }
                            },
                            style: .secondary,
                            textFont: .rsButtonSmall
                        )

                        BigButton(
                            title: "Play Reversed",
                            icon: "play.circle.fill",
                            color: .rsGradientCyan,
                            action: {
                                if let reversed = session?.reversedRecording {
                                    viewModel.playRecording(reversed)
                                }
                            },
                            style: .secondary,
                            textFont: .rsButtonSmall
                        )
                    }

                    // Row 2: Play Attempt | Play Attempt Reversed
                    HStack(spacing: 12) {
                        BigButton(
                            title: "Play Attempt",
                            icon: "play.circle.fill",
                            color: .rsGradientCyan,
                            action: {
                                if let attempt = session?.attemptRecording {
                                    viewModel.playRecording(attempt)
                                }
                            },
                            style: .secondary,
                            textFont: .rsButtonSmall
                        )

                        BigButton(
                            title: "Play Attempt Reversed",
                            icon: "play.circle.fill",
                            color: .rsGradientCyan,
                            action: {
                                if let reversedAttempt = session?.reversedAttempt {
                                    viewModel.playRecording(reversedAttempt)
                                }
                            },
                            isEnabled: session?.reversedAttempt != nil,
                            style: .secondary,
                            textFont: .rsButtonSmall
                        )
                    }
                }
            }
            // Single row: Play Original | Play Reversed (when reversed exists but no attempt yet)
            else if session?.reversedRecording != nil && session?.attemptRecording == nil && !isRecording && !isPlaying {
                HStack(spacing: 12) {
                    BigButton(
                        title: "Play Original",
                        icon: "play.circle.fill",
                        color: .rsGradientCyan,
                        action: {
                            if let original = session?.originalRecording {
                                viewModel.playRecording(original)
                            }
                        },
                        style: .secondary
                    )

                    BigButton(
                        title: "Play Reversed",
                        icon: "play.circle.fill",
                        color: .rsGradientCyan,
                        action: {
                            if let reversed = session?.reversedRecording {
                                viewModel.playRecording(reversed)
                            }
                        },
                        style: .secondary
                    )
                }
            }

            // Record Your Attempt (only shown when reversed exists and no attempt yet)
            if session?.reversedRecording != nil && session?.attemptRecording == nil {
                BigButton(
                    title: isRecording ? "Stop Recording" : "Record Your Attempt",
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

            // Compare Results (shown when attempt exists)
            if session?.attemptRecording != nil && !isRecording {
                BigButton(
                    title: "Compare Results",
                    icon: "chart.bar.fill",
                    color: .rsSuccess,
                    action: {
                        if session?.reversedAttempt == nil {
                            viewModel.reverseAttempt()
                            // Comparison will show automatically when score is ready (via onChange)
                        } else {
                            showComparisonView = true
                        }
                    },
                    isLoading: viewModel.isReversing,
                    style: .primary
                )
            }

            // Always: Start New Session button
            CompactButton(
                title: "Start New Session",
                icon: "plus.circle.fill",
                action: { viewModel.startNewSession() }
            )
            .padding(.top, 8)
        }
    }


    // MARK: - Tip Text

    private func tipText(_ text: String) -> some View {
        Text(text)
            .font(.rsCaption)
            .foregroundColor(.rsSecondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 300)
            .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    MainViewPremium()
}
