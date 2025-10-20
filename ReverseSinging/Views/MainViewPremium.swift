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

                    // Step indicator
                    if viewModel.appState.currentSession != nil {
                        StepIndicator(currentStep: viewModel.appState.currentGameStep)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                            .animatedCard(delay: 0.05)
                    }

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

                    // Stage progress (when idle/between steps)
                    if shouldShowStages {
                        stageProgressView
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                            .animatedCard(delay: 0.2)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }

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
            .onChange(of: viewModel.appState.currentGameStep) { oldStep, newStep in
                // Auto-play reversed audio when entering Step 2 (after auto-reverse completes)
                if newStep == 2 && oldStep != 2 {
                    // Delay slightly to let the UI update
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.autoPlayReversedAudio()
                    }
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

    // MARK: - Stage Progress

    private var shouldShowStages: Bool {
        let session = viewModel.appState.currentSession
        return session != nil && !shouldShowTimer
    }

    private var stageProgressView: some View {
        HStack(spacing: 16) {
            stageItem(
                "Original",
                icon: "mic.fill",
                isComplete: viewModel.appState.currentSession?.originalRecording != nil
            )

            stageDivider

            stageItem(
                "Reversed",
                icon: "arrow.triangle.2.circlepath",
                isComplete: viewModel.appState.currentSession?.reversedRecording != nil
            )

            stageDivider

            stageItem(
                "Attempt",
                icon: "waveform.path.ecg",
                isComplete: viewModel.appState.currentSession?.attemptRecording != nil
            )
        }
        .padding(20)
        .cardStyle(shadow: .subtle)
    }

    private func stageItem(_ title: String, icon: String, isComplete: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.rsHeadingSmall)
                .foregroundColor(isComplete ? .rsGold : .rsSecondaryText)

            Text(title)
                .font(.rsCaption)
                .foregroundColor(isComplete ? .rsText : .rsSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var stageDivider: some View {
        Image(systemName: "arrow.right")
            .font(.rsCaption)
            .foregroundColor(.rsSecondaryText)
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
            let currentStep = viewModel.appState.currentGameStep
            let isRecording = viewModel.appState.recordingState == .recording

            // STEP 1: Record Original (auto-reverses when done)
            if session?.reversedRecording == nil {
                // Tip
                tipText(isRecording
                    ? "Sing clearly - the waveform shows your voice level"
                    : "Record yourself singing a phrase or saying something fun")

                if isRecording {
                    BigButton(
                        title: "Stop Recording",
                        icon: "stop.circle.fill",
                        color: .rsRecording,
                        action: { viewModel.stopRecording() },
                        style: .primary
                    )
                } else {
                    BigButton(
                        title: "Record Original",
                        icon: "mic.fill",
                        color: .rsRecording,
                        action: { viewModel.startRecording() },
                        style: .primary
                    )
                }
                // No back button on Step 1
            }
            // STEP 2: Record Your Attempt (after auto-reverse)
            else if session?.attemptRecording == nil {
                VStack(spacing: 12) {
                    // Tip
                    tipText(isRecording
                        ? "Match the rhythm and melody you heard in the reversed version"
                        : "Listen to the reversed audio, then try to sing it backwards")

                    // Primary action
                    if isRecording {
                        BigButton(
                            title: "Stop Recording",
                            icon: "stop.circle.fill",
                            color: .rsRecording,
                            action: { viewModel.stopRecording(type: .attempt) },
                            style: .primary
                        )
                    } else {
                        BigButton(
                            title: "Record Your Attempt",
                            icon: "mic.fill",
                            color: .rsRecording,
                            action: { viewModel.startRecording() },
                            style: .primary
                        )
                    }

                    // Secondary: Listen Again (only when not recording)
                    if !isRecording {
                        CompactButton(
                            title: "Listen Again",
                            icon: "play.fill",
                            action: {
                                if let reversed = session?.reversedRecording {
                                    viewModel.playRecording(reversed)
                                }
                            }
                        )
                    }
                }

                backButton(currentStep: currentStep)
            }
            // STEP 3: See Results
            else {
                // Tip
                tipText("Ready to see how close you got? Let's compare your recordings!")

                BigButton(
                    title: "See Results",
                    icon: "chart.bar.fill",
                    color: .rsGold,
                    action: {
                        // If not yet reversed, reverse and calculate
                        if session?.reversedAttempt == nil {
                            viewModel.reverseAttempt()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if viewModel.appState.similarityScore != nil {
                                    showComparisonView = true
                                }
                            }
                        } else {
                            // Already calculated, just show results
                            showComparisonView = true
                        }
                    },
                    isLoading: viewModel.isReversing,
                    style: .primary
                )

                backButton(currentStep: currentStep)
            }
        }
    }

    // MARK: - Back Button

    private func backButton(currentStep: Int) -> some View {
        HStack {
            Button(action: {
                viewModel.goBackOneStep()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.rsBodySmall)
                    Text("Back")
                        .font(.rsBodyMedium)
                }
                .foregroundColor(.rsSecondaryText)
            }
            .padding(.top, 8)

            Spacer()
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
