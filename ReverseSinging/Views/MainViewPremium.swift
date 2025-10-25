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
                style: waveformStyle
            )
            .frame(height: 140)
            .padding(.horizontal, 20)
            .padding(.vertical, waveformPadding)
        }
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow(.card)
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
        // Hide waveform once audio is recorded or when playing
        if viewModel.appState.currentSession?.originalRecording != nil {
            return false
        }

        switch viewModel.appState.recordingState {
        case .playing:
            return false
        default:
            return true
        }
    }

    // MARK: - Timer Card

    private var shouldShowTimer: Bool {
        switch viewModel.appState.recordingState {
        case .recording, .playing:
            return true
        default:
            return false
        }
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
            )
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
        case .recording:
            return viewModel.recordingDuration
        case .playing:
            return viewModel.playbackProgress
        default:
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

            // Button 1: Record Original (only shown when no recording exists)
            if session?.originalRecording == nil {
                BigButton(
                    title: isRecording ? "Stop Recording" : "Record Original",
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

            // Button 2: Play/Stop Reverse Audio (hidden while recording)
            if session?.reversedRecording != nil && !isRecording {
                BigButton(
                    title: viewModel.appState.recordingState == .playing ? "Stop Playback" : "Play Reverse Audio",
                    icon: viewModel.appState.recordingState == .playing ? "stop.circle.fill" : "play.circle.fill",
                    color: .rsGradientCyan,
                    action: {
                        if viewModel.appState.recordingState == .playing {
                            viewModel.stopPlayback()
                        } else if let reversed = session?.reversedRecording {
                            viewModel.playRecording(reversed)
                        }
                    },
                    style: .primary
                )
            }

            // Button 3: Record Your Attempt (only shown when reversed exists and no attempt yet)
            if session?.reversedRecording != nil && session?.attemptRecording == nil {
                BigButton(
                    title: isRecording ? "Stop Recording Attempt" : "Record Your Attempt",
                    icon: isRecording ? "stop.circle.fill" : "mic.fill",
                    color: .rsRecording,
                    action: {
                        if isRecording {
                            viewModel.stopRecording(type: .attempt)
                        } else {
                            viewModel.startRecording()
                        }
                    },
                    style: .secondary
                )
            }

            // Button 4: Compare Results (hidden while recording)
            if session?.attemptRecording != nil && !isRecording {
                BigButton(
                    title: "Compare Results",
                    icon: "chart.bar.fill",
                    color: .rsSuccess,
                    action: {
                        if session?.reversedAttempt == nil {
                            viewModel.reverseAttempt()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if viewModel.appState.similarityScore != nil {
                                    showComparisonView = true
                                }
                            }
                        } else {
                            showComparisonView = true
                        }
                    },
                    isLoading: viewModel.isReversing,
                    style: .primary
                )
            }

            // Start New Session button (always visible)
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
