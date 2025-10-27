//
//  MainView.swift
//  ReverseSinging
//
//  Main app view with recording flow
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = AudioViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rsBackgroundAdaptive(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    headerView

                    Spacer()

                    // Waveform
                    waveformSection

                    // Current session status
                    sessionStatusView

                    // Playback controls
                    if shouldShowPlaybackControls {
                        playbackControlsView
                    }

                    Spacer()

                    // Action buttons
                    actionButtonsView

                    // Bottom controls
                    bottomControlsView
                }
                .padding()
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Reverso")
                    .font(.rsHeadingLarge)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                Text("Voice Flip")
                    .font(.rsBodyMedium)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
            }

            Spacer()

            Button(action: { viewModel.showSessionList = true }) {
                Image(systemName: "list.bullet")
                    .font(.rsHeadingMedium)
                    .foregroundColor(.rsTurquoise)
            }
        }
    }

    // MARK: - Waveform

    private var waveformSection: some View {
        VStack(spacing: 16) {
            if case .recording = viewModel.appState.recordingState {
                RecordingIndicator()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.rsSecondaryBackground)
                    .frame(height: 120)

                if case .recording = viewModel.appState.recordingState {
                    WaveformView(
                        level: viewModel.recordingLevel,
                        barCount: 50,
                        color: .rsRecording
                    )
                    .padding()
                } else if case .playing = viewModel.appState.recordingState {
                    WaveformView(
                        level: 0.7,
                        barCount: 50,
                        color: .rsPlaying
                    )
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 40))
                            .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))

                        Text("Ready to record")
                            .font(.rsBodyMedium)
                            .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                    }
                }
            }
        }
    }

    // MARK: - Session Status

    private var sessionStatusView: some View {
        Group {
            if let session = viewModel.appState.currentSession {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        statusBadge(
                            "Original",
                            icon: "mic.fill",
                            isComplete: session.originalRecording != nil
                        )

                        Image(systemName: "arrow.right")
                            .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))

                        statusBadge(
                            "Reversed",
                            icon: "arrow.triangle.2.circlepath",
                            isComplete: session.reversedRecording != nil
                        )

                        Image(systemName: "arrow.right")
                            .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))

                        statusBadge(
                            "Attempt",
                            icon: "person.wave.2.fill",
                            isComplete: session.attemptRecording != nil
                        )
                    }
                    .font(.rsCaption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.rsTertiaryBackground)
                )
            }
        }
    }

    private func statusBadge(_ title: String, icon: String, isComplete: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.rsBodyLarge)
                .foregroundColor(isComplete ? .rsSuccess : .rsSecondaryText)

            Text(title)
                .font(.rsCaption)
                .foregroundColor(isComplete ? .rsText : .rsSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Playback Controls

    private var shouldShowPlaybackControls: Bool {
        guard let session = viewModel.appState.currentSession else { return false }
        return session.reversedRecording != nil || session.attemptRecording != nil
    }

    private var playbackControlsView: some View {
        VStack(spacing: 16) {
            // Speed control
            VStack(spacing: 8) {
                HStack {
                    Text("Speed")
                        .font(.rsBodyMedium)
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                    Spacer()

                    Text(String(format: "%.1fx", viewModel.appState.playbackSpeed))
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsTurquoise)
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
                .tint(.rsTurquoise)
            }

            // Loop toggle
            Button(action: { viewModel.toggleLooping() }) {
                HStack {
                    Image(systemName: viewModel.appState.isLooping ? "repeat.circle.fill" : "repeat.circle")
                        .font(.rsHeadingMedium)

                    Text(viewModel.appState.isLooping ? "Loop: On" : "Loop: Off")
                        .font(.rsBodyMedium)
                }
                .foregroundColor(viewModel.appState.isLooping ? .rsTurquoise : .rsSecondaryText)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.rsTertiaryBackground)
        )
    }

    // MARK: - Action Buttons

    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            let session = viewModel.appState.currentSession

            // Step 1: Record or import original
            if session?.originalRecording == nil {
                if case .recording = viewModel.appState.recordingState {
                    BigButton(
                        title: "Stop Recording",
                        icon: "stop.fill",
                        color: .red,
                        action: { viewModel.stopRecording() }
                    )
                } else {
                    BigButton(
                        title: "Record Audio",
                        icon: "mic.fill",
                        color: .red,
                        action: { viewModel.startRecording() }
                    )
                }
            }
            // Step 2: Reverse the original
            else if session?.reversedRecording == nil {
                HStack(spacing: 12) {
                    BigButton(
                        title: "Play Original",
                        icon: "play.fill",
                        color: .green,
                        action: {
                            if let recording = session?.originalRecording {
                                viewModel.playRecording(recording)
                            }
                        }
                    )

                    BigButton(
                        title: "Reverse",
                        icon: "arrow.triangle.2.circlepath",
                        color: .purple,
                        action: { viewModel.reverseCurrentRecording() },
                        isLoading: viewModel.isReversing
                    )
                }
            }
            // Step 3: Record attempt
            else if session?.attemptRecording == nil {
                if case .recording = viewModel.appState.recordingState {
                    BigButton(
                        title: "Stop Attempt",
                        icon: "stop.fill",
                        color: .red,
                        action: { viewModel.stopRecording(type: .attempt) }
                    )
                } else {
                    HStack(spacing: 12) {
                        BigButton(
                            title: "Play Reversed",
                            icon: "play.fill",
                            color: .green,
                            action: {
                                if let recording = session?.reversedRecording {
                                    viewModel.playRecording(recording)
                                }
                            }
                        )

                        BigButton(
                            title: "Record Attempt",
                            icon: "mic.fill",
                            color: .orange,
                            action: { viewModel.startRecording() }
                        )
                    }
                }
            }
            // Step 4: Compare
            else {
                BigButton(
                    title: "Reverse & Compare",
                    icon: "arrow.triangle.2.circlepath",
                    color: .purple,
                    action: { viewModel.reverseAttempt() },
                    isLoading: viewModel.isReversing
                )

                HStack(spacing: 12) {
                    BigButton(
                        title: "Try Again",
                        icon: "arrow.counterclockwise",
                        color: .orange,
                        action: { viewModel.startNewSession() }
                    )

                    BigButton(
                        title: "Save Session",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        action: { viewModel.saveSession() }
                    )
                }
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControlsView: some View {
        HStack {
            if case .playing = viewModel.appState.recordingState {
                Button(action: { viewModel.stopPlayback() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.rsBodyMedium)
                    .foregroundColor(.rsError)
                }
            }

            Spacer()

            if let session = viewModel.appState.currentSession,
               !session.recordings.isEmpty {
                Button(action: { viewModel.startNewSession() }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("New Session")
                    }
                    .font(.rsBodyMedium)
                    .foregroundColor(.rsTurquoise)
                }
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
    MainView()
}
