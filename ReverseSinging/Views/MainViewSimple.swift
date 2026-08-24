//
//  MainViewSimple.swift
//  ReverseSinging
//
//  Simple UI with three large buttons
//

import SwiftUI

struct MainViewSimple: View {
    @EnvironmentObject var viewModel: AudioViewModel
    @State private var displayedTip: String = ""
    @State private var showNewSessionAlert = false
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
                    // Main content
                    mainContentView
                }

                // Fixed header overlay (always visible)
                fixedHeaderOverlay

                // Overlays (processing, tips, etc.)
                overlaysView
            }
            .onAppear {
                viewModel.checkPermissionStatus()
                displayedTip = currentTip ?? ""
                AnalyticsManager.shared.trackScreenViewed(screenName: "MainViewSimple")
            }
            .onChange(of: currentTip) { _, newTip in
                withAnimation(.rsSpring) {
                    displayedTip = newTip ?? ""
                }
            }
            .sheet(isPresented: $viewModel.showSessionList) {
                SessionListView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: $viewModel.showPermissionAlert) {
                Button(Strings.Main.Alert.settings, action: openSettings)
                Button(Strings.Main.Alert.cancel, role: .cancel) {}
            } message: {
                Text(Strings.Main.Alert.microphoneRequiredMessage)
            }
            .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button(Strings.Main.Alert.ok, role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert(Strings.Main.Alert.startNewSessionTitle, isPresented: $showNewSessionAlert) {
                Button(Strings.Main.Alert.cancel, role: .cancel) {}
                Button(Strings.Main.Alert.startNewSessionButton, role: .destructive) {
                    viewModel.startNewSession()
                }
            } message: {
                Text(Strings.Main.Alert.startNewSessionMessage)
            }
        }
    }

    // MARK: - Empty State

    private var microphonePermissionEmptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("microphone")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .scaleIn(delay: 0.1)

            VStack(spacing: 16) {
                Text(Strings.Main.EmptyState.title)
                    .font(.rsHeadingMedium)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)

                Text(Strings.Main.EmptyState.message)
                    .font(.rsBodyMedium)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 24)
            }
            .fadeIn(delay: 0.2)

            BigButton(
                title: Strings.Main.EmptyState.button,
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
        VStack(spacing: 0) {
            // Top spacer for fixed header
            Spacer()
                .frame(height: 120)

            // Recording indicator
            SimpleRecordingIndicator(
                state: viewModel.appState.recordingState,
                isPlayingReversed: isPlayingReversedAudio
            )
            .padding(.bottom, 16)

            // Timer display
            SimpleTimerDisplay(
                duration: displayDuration,
                isVisible: shouldShowTimer
            )
            .padding(.bottom, 32)

            Spacer()

            // Three large buttons
            threeButtonStack
                .padding(.horizontal, 24)

            Spacer()

            // Bottom spacer for tips
            Color.clear
                .frame(height: 100)
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

                    // Header buttons
                    HStack(spacing: 12) {
                        // Archive button
                        Button(action: { viewModel.showSessionList = true }) {
                            Image(systemName: "archivebox")
                                .font(.rsHeadingSmall)
                                .foregroundColor(.accent)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.rsCardBackground(for: colorScheme).opacity(0.95))
                                )
                        }

                        // Settings button
                        Button(action: { viewModel.showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.rsHeadingSmall)
                                .foregroundColor(.accent)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.rsCardBackground(for: colorScheme).opacity(0.95))
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Three Button Stack

    private var threeButtonStack: some View {
        VStack(spacing: 16) {
            // Button 1: Record Audio / Stop Recording (Red)
            // Dynamic button that changes based on recording state
            LargeActionButton(
                title: isRecording ? "Stop Recording" : "Record Audio",
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
                title: "Play Recorded",
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
                title: "Play Reverse",
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
            // Processing indicator overlay
            if viewModel.isReversing {
                ProcessingIndicator(message: Strings.Main.processingReversingAudio)
                    .transition(.scale.combined(with: .opacity))
            }

            // Tip overlay at bottom
            if viewModel.hasRecordingPermission, let tip = currentTip, !tip.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    ZStack(alignment: .top) {
                        Image("fade")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                            .rotationEffect(.degrees(180))

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

    // MARK: - Tip Text

    private func tipText(_ text: String) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsTurquoise)

                    Text(text)
                        .font(.rsBodyMedium)
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .glassEffect()
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsTurquoise)

                    Text(text)
                        .font(.rsBodyMedium)
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.rsCardBackground(for: colorScheme))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
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

    private var isPlayingReversedAudio: Bool {
        guard viewModel.appState.recordingState == .playing else { return false }
        // Determine if currently playing reversed audio based on which recording is being played
        // This is a simplified check - you might need more logic based on your actual implementation
        return viewModel.appState.currentSession?.reversedRecording != nil
    }

    // MARK: - Button States

    private var isRecording: Bool {
        return viewModel.appState.recordingState == .recording
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
                return "Recording original audio"
            } else {
                return "Recording your attempt"
            }
        } else {
            let session = viewModel.appState.currentSession
            if session?.originalRecording == nil {
                return "Tap to record audio"
            } else if session?.attemptRecording == nil {
                return "Record your singing attempt"
            } else {
                return "Re-record your attempt"
            }
        }
    }

    private var subtitleForPlayButton: String? {
        let session = viewModel.appState.currentSession
        if session?.attemptRecording != nil {
            return "Play your attempt"
        } else if session?.originalRecording != nil {
            return "Play original recording"
        }
        return "No recording available"
    }

    private var subtitleForReverseButton: String? {
        let session = viewModel.appState.currentSession
        if session?.reversedAttempt != nil {
            return "Play reversed attempt"
        } else if session?.reversedRecording != nil {
            return "Play reversed original"
        }
        return "No reversed audio available"
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
            // Start recording
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

    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Large Action Button

struct LargeActionButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let dotCount: Int  // Number of dots to show (0-3)
    let color: Color
    let isEnabled: Bool
    let recordingLevel: Float  // Audio level 0-1 for animation
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var smoothedLevels: [CGFloat] = [0, 0, 0]
    @State private var basePulse: CGFloat = 0

    var body: some View {
        Button(action: {
            if isEnabled {
                HapticManager.shared.impact(.medium)
                action()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 64)

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(title)
                        .font(.rsButtonLarge)
                        .foregroundColor(.white)

                    // Subtitle
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.rsCaption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer()

                // Audio-reactive dots (if any)
                if dotCount > 0 {
                    HStack(spacing: 8) {
                        ForEach(0..<dotCount, id: \.self) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .scaleEffect(dotScale(for: index))
                                .animation(.easeInOut(duration: 0.15), value: smoothedLevels[index])
                        }
                    }
                    .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isEnabled ? color : color.opacity(0.3))
            )
            .cardShadow(isEnabled ? .elevated : .subtle)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .disabled(!isEnabled)
        .animation(.rsSpring, value: isEnabled)
        .onChange(of: recordingLevel) { _, newLevel in
            updateDotLevels(newLevel: CGFloat(newLevel))
        }
        .onAppear {
            // Start gentle base pulse
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                basePulse = 0.1
            }
        }
    }

    // MARK: - Animation Helpers

    private func dotScale(for index: Int) -> CGFloat {
        let smoothedLevel = smoothedLevels[index]

        // Base pulse when quiet (0.9-1.0)
        let basePulseScale = 0.9 + basePulse

        if smoothedLevel < 0.05 {
            // Very quiet - just use base pulse
            return basePulseScale
        }

        // Audio-reactive scaling: 0.7 (silent) to 1.5 (loud)
        let minScale: CGFloat = 0.7
        let maxScale: CGFloat = 1.5
        let audioScale = minScale + (smoothedLevel * (maxScale - minScale))

        // Blend base pulse with audio reactivity
        return max(basePulseScale, audioScale)
    }

    private func updateDotLevels(newLevel: CGFloat) {
        // Stagger delays: dot 0 gets full level, dot 1 and 2 get slightly delayed
        let staggerFactor: [CGFloat] = [1.0, 0.85, 0.7]

        for index in 0..<min(dotCount, 3) {
            let targetLevel = newLevel * staggerFactor[index]

            // Apply momentum smoothing (70% previous, 30% new)
            let momentum: CGFloat = 0.7
            smoothedLevels[index] = smoothedLevels[index] * momentum + targetLevel * (1 - momentum)
        }
    }
}

#Preview {
    MainViewSimple()
        .environmentObject(AudioViewModel())
}
