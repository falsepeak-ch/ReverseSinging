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

                    // Waveform visualization
                    waveformCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .animatedCard(delay: 0.1)

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

                    // Playback controls
                    if shouldShowPlaybackControls {
                        playbackControlsCard
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                            .animatedCard(delay: 0.25)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

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
                    .foregroundColor(.rsGold)
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
            state: timerState
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

    private var shouldShowPlaybackControls: Bool {
        guard let session = viewModel.appState.currentSession else { return false }
        return session.reversedRecording != nil || session.attemptRecording != nil
    }

    private var playbackControlsCard: some View {
        VStack(spacing: 20) {
            // Speed control
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "gauge")
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsGold)

                    Text("Playback Speed")
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsText)

                    Spacer()

                    Text(String(format: "%.1fx", viewModel.appState.playbackSpeed))
                        .font(.rsHeadingSmall)
                        .foregroundColor(.rsGold)
                        .monospacedDigit()
                }

                Slider(
                    value: .init(
                        get: { viewModel.appState.playbackSpeed },
                        set: { viewModel.setPlaybackSpeed($0) }
                    ),
                    in: 0.5...2.0,
                    step: 0.1
                )
                .tint(.rsGold)
            }

            Divider()

            // Loop toggle
            HStack {
                Image(systemName: viewModel.appState.isLooping ? "repeat.circle.fill" : "repeat.circle")
                    .font(.rsHeadingSmall)
                    .foregroundColor(viewModel.appState.isLooping ? .rsGold : .rsSecondaryText)

                Text("Loop Playback")
                    .font(.rsBodyMedium)
                    .foregroundColor(.rsText)

                Spacer()

                Toggle("", isOn: .init(
                    get: { viewModel.appState.isLooping },
                    set: { _ in viewModel.toggleLooping() }
                ))
                .tint(.rsGold)
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            let session = viewModel.appState.currentSession
            let isRecording = viewModel.appState.recordingState == .recording

            // Button 1: Record Original (always enabled to start the flow)
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
                isEnabled: session?.originalRecording == nil,
                style: .primary
            )

            // Button 2: Play Reverse Audio (auto-reversed after recording)
            BigButton(
                title: "Play Reverse Audio",
                icon: "play.circle.fill",
                color: .rsGold,
                action: {
                    if let reversed = session?.reversedRecording {
                        viewModel.playRecording(reversed)
                    }
                },
                isEnabled: session?.reversedRecording != nil,
                style: .primary
            )

            // Button 3: Record Your Attempt
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
                isEnabled: session?.reversedRecording != nil && session?.attemptRecording == nil,
                style: .secondary
            )

            // Button 4: Compare Results
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
                isEnabled: session?.attemptRecording != nil,
                isLoading: viewModel.isReversing && session?.attemptRecording != nil,
                style: .primary
            )

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
