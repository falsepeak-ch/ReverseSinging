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
    @State private var displayedTip: String = ""
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


                    // Removed stage progress - simplified to single screen
                    // Playback controls now integrated into TimerCard

                    // Action buttons
                    actionButtonsSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
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
            .overlay(alignment: .bottom) {
                if let tip = currentTip, !tip.isEmpty {
                    tipText(tip)
                        .id(displayedTip)  // Force re-creation for animation
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .background(
                            Color.rsBackground
                                .ignoresSafeArea(edges: .bottom)
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .onChange(of: currentTip) { _, newTip in
                withAnimation(.rsSpring) {
                    displayedTip = newTip ?? ""
                }
            }
            .onAppear {
                displayedTip = currentTip ?? ""
            }
            .sheet(isPresented: $viewModel.showSessionList) {
                SessionListView(viewModel: viewModel)
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
                    .foregroundColor(.rsTurquoise)
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
            return "Tap Record Audio to begin your reverse singing challenge"
        }

        // Hide tips during recording or playing
        if case .recording = viewModel.appState.recordingState {
            return nil
        }
        if case .playing = viewModel.appState.recordingState {
            return nil
        }

        // Step-based tips
        if session.attemptRecording != nil {
            return "Tap Re-record to improve your attempt, or New Session to record a new song"
        } else if session.reversedRecording != nil {
            return "Listen to the reversed audio, then record your singing attempt"
        } else {
            return nil  // Hide during auto-reverse processing
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

            // Record Your Attempt (only shown when reversed exists and no attempt yet, hidden when playing)
            if session?.reversedRecording != nil && session?.attemptRecording == nil && !isPlaying {
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

            // ScoreCard (shown when score is available)
            if let score = viewModel.appState.similarityScore, !isRecording {
                ScoreCard(score: score)
                    .frame(maxWidth: .infinity)
            }

            // Bottom buttons: Re-record and Start New Session (both compact)
            HStack(spacing: 12) {
                if session?.attemptRecording != nil && !isRecording {
                    CompactButton(
                        title: "Re-record",
                        icon: "record.circle",
                        action: {
                            viewModel.reRecordAttempt()
                            viewModel.startRecording()
                        },
                        color: .rsRecording
                    )
                }

                CompactButton(
                    title: "New Session",
                    icon: "plus.circle.fill",
                    action: { viewModel.startNewSession() }
                )
            }
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
