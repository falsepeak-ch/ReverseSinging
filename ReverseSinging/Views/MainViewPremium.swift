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
    @State private var showNewSessionAlert = false
    @State private var isScoreVisible = true
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color layer
                Color.rsBackgroundAdaptive(for: colorScheme)
                    .ignoresSafeArea()

                // Show empty state if permission is denied
                if !viewModel.hasRecordingPermission {
                    microphonePermissionEmptyState
                        .transition(.opacity)
                } else {
                    // Scrollable content layer
                    mainContentView
                }

                // Fixed header overlay (always visible)
                fixedHeaderOverlay

                // Overlays (processing, toasts, etc.)
                overlaysView
            }
            .onAppear {
                viewModel.checkPermissionStatus()
                displayedTip = currentTip ?? ""
            }
            .onChange(of: currentTip) { _, newTip in
                withAnimation(.rsSpring) {
                    displayedTip = newTip ?? ""
                }
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
            .alert("Start New Session?", isPresented: $showNewSessionAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Start New Session", role: .destructive) {
                    viewModel.startNewSession()
                }
            } message: {
                Text("Your current session will be saved to the archive. This will start a fresh recording session.")
            }
        }
    }

    // MARK: - Empty State

    private var microphonePermissionEmptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            // Microphone image
            Image("microphone")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .scaleIn(delay: 0.1)

            VStack(spacing: 16) {
                // Title
                Text("Microphone Access Required")
                    .font(.rsHeadingMedium)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)

                // Description
                Text("To use Reverso, please enable microphone access in your device settings. This allows you to record and reverse audio.")
                    .font(.rsBodyMedium)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 24)
            }
            .fadeIn(delay: 0.2)

            // Open Settings button
            BigButton(
                title: "Open Settings",
                icon: "gearshape.fill",
                color: .rsTurquoise,
                action: openSettings,
                style: .primary
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .fadeIn(delay: 0.3)

            Spacer()
        }
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

    // MARK: - Fixed Header

    private var fixedHeaderOverlay: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // Fade background image
                Image("fade")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()

                // Header content
                HStack {
                    Image(viewModel.hasRecordingPermission ? "icon-lettering" : "lettering")
                        .resizable()
                        .scaledToFit()
                        .frame(height: viewModel.hasRecordingPermission ? 48 : 30)

                    Spacer()

                    Button(action: { viewModel.showSessionList = true }) {
                        if #available(iOS 26.0, *) {
                            Image(systemName: "archivebox")
                                .font(.rsHeadingSmall)
                                .foregroundColor(.accent)
                                .frame(width: 44, height: 44)
                                .glassEffect()
                        } else {
                            Image(systemName: "archivebox")
                                .font(.rsHeadingSmall)
                                .foregroundColor(.rsCharcoal)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.rsButtonPrimaryCream)
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Overlays

    private var overlaysView: some View {
        ZStack {
            // Success toast overlay
            if showSuccessToast {
                VStack {
                    SuccessToast(message: "Session saved!", isPresented: $showSuccessToast)
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
                ProcessingIndicator(message: "Reversing audio...")
                    .transition(.scale.combined(with: .opacity))
            }

            // Tip overlay at bottom (only shown when permission is granted)
            if viewModel.hasRecordingPermission, let tip = currentTip, !tip.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    ZStack(alignment: .top) {
                        // Fade background image (rotated 180 degrees to fade upward)
                        Image("fade")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                            .rotationEffect(.degrees(180))

                        // Tip card content on top
                        tipText(tip)
                            .id(displayedTip)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .ignoresSafeArea(edges: .bottom)
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

        // Show tips during recording
        if case .recording = viewModel.appState.recordingState {
            if session.attemptRecording != nil {
                // Re-recording attempt
                return "Record your singing attempt while listening to the reversed audio"
            } else if session.reversedRecording != nil {
                // Recording attempt for first time
                return "Record your singing attempt while listening to the reversed audio"
            } else {
                // Recording original
                return "Record the song you want to sing in reverse"
            }
        }

        // Show tips during playback
        if case .playing = viewModel.appState.recordingState {
            return "Tap any play button to switch between recordings, or tap stop to pause"
        }

        // Step-based tips for idle states
        if session.attemptRecording != nil {
            return "Tap Re-record to improve your attempt, or New Session to record a new song"
        } else if session.reversedRecording != nil {
            return "Listen to the reversed audio, then record your singing attempt"
        } else if session.originalRecording != nil {
            // Original recording exists but not reversed yet - processing
            return "Processing your audio... This will only take a moment"
        } else {
            // Initial state - no recordings yet
            return "Tap Record Audio to record the song you want to reverse"
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
                ScoreCard(score: score, isVisible: $isScoreVisible)
                    .frame(maxWidth: .infinity)
            }

            // Bottom buttons: Re-record and Start New Session
            HStack(spacing: 12) {
                if session?.attemptRecording != nil && !isRecording {
                    BigButton(
                        title: "Re-record",
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
                        title: "New Session",
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


    // MARK: - Tip Card

    private func tipText(_ text: String) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "info.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                        .frame(width: 20, height: 20)
                    
                    Text(text)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 0)
                }
                .padding(16)
                .glassEffect()
            } else {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "info.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                        .frame(width: 20, height: 20)
                    
                    Text(text)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.rsCardBackground(for: colorScheme))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
        }
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
