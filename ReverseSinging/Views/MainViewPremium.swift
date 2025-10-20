//
//  MainViewPremium.swift
//  ReverseSinging
//
//  Premium redesigned main view
//

import SwiftUI
import UniformTypeIdentifiers

struct MainViewPremium: View {
    @StateObject private var viewModel = AudioViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Minimal header
                    headerView
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    // Waveform visualization
                    waveformCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    // Timer card (prominent when recording/playing)
                    if shouldShowTimer {
                        timerCard
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }

                    // Stage progress (when idle/between steps)
                    if shouldShowStages {
                        stageProgressView
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }

                    // Playback controls
                    if shouldShowPlaybackControls {
                        playbackControlsCard
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }

                    // Action buttons
                    actionButtonsSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    // Bottom control bar
                    bottomBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.rsBackground.ignoresSafeArea())
            .sheet(isPresented: $viewModel.showSessionList) {
                SessionListView(viewModel: viewModel)
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(viewModel: viewModel)
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
        VStack(spacing: 12) {
            let session = viewModel.appState.currentSession

            // Step 1: Record or import original
            if session?.originalRecording == nil {
                if case .recording = viewModel.appState.recordingState {
                    BigButton(
                        title: "Stop Recording",
                        icon: "stop.circle.fill",
                        color: .rsRecording,
                        action: { viewModel.stopRecording() },
                        style: .primary
                    )
                } else {
                    HStack(spacing: 12) {
                        BigButton(
                            title: "Record",
                            icon: "mic.fill",
                            color: .rsRecording,
                            action: { viewModel.startRecording() },
                            style: .primary
                        )

                        BigButton(
                            title: "Import",
                            icon: "square.and.arrow.down",
                            color: .rsGold,
                            action: { showFilePicker = true },
                            style: .secondary
                        )
                    }
                }
            }
            // Step 2: Reverse the original
            else if session?.reversedRecording == nil {
                HStack(spacing: 12) {
                    BigButton(
                        title: "Listen",
                        icon: "play.fill",
                        color: .rsPlaying,
                        action: {
                            if let recording = session?.originalRecording {
                                viewModel.playRecording(recording)
                            }
                        },
                        style: .secondary
                    )

                    BigButton(
                        title: "Reverse",
                        icon: "arrow.triangle.2.circlepath",
                        color: .rsGold,
                        action: { viewModel.reverseCurrentRecording() },
                        isLoading: viewModel.isReversing,
                        style: .primary
                    )
                }
            }
            // Step 3: Record attempt
            else if session?.attemptRecording == nil {
                if case .recording = viewModel.appState.recordingState {
                    BigButton(
                        title: "Stop Attempt",
                        icon: "stop.circle.fill",
                        color: .rsRecording,
                        action: { viewModel.stopRecording(type: .attempt) },
                        style: .primary
                    )
                } else {
                    HStack(spacing: 12) {
                        BigButton(
                            title: "Play Reversed",
                            icon: "play.fill",
                            color: .rsPlaying,
                            action: {
                                if let recording = session?.reversedRecording {
                                    viewModel.playRecording(recording)
                                }
                            },
                            style: .secondary
                        )

                        BigButton(
                            title: "Record Attempt",
                            icon: "mic.fill",
                            color: .rsGold,
                            action: { viewModel.startRecording() },
                            style: .primary
                        )
                    }
                }
            }
            // Step 4: Compare
            else {
                BigButton(
                    title: "Reverse & Compare",
                    icon: "arrow.triangle.2.circlepath",
                    color: .rsGold,
                    action: { viewModel.reverseAttempt() },
                    isLoading: viewModel.isReversing,
                    style: .primary
                )

                HStack(spacing: 12) {
                    BigButton(
                        title: "New Session",
                        icon: "arrow.counterclockwise",
                        color: .rsGold,
                        action: { viewModel.startNewSession() },
                        style: .secondary
                    )

                    BigButton(
                        title: "Save",
                        icon: "checkmark.circle.fill",
                        color: .rsSuccess,
                        action: { viewModel.saveSession() },
                        style: .primary
                    )
                }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if case .playing = viewModel.appState.recordingState {
                CompactButton(
                    title: "Stop",
                    icon: "stop.fill",
                    action: { viewModel.stopPlayback() },
                    color: .rsError
                )
            }

            Spacer()

            if let session = viewModel.appState.currentSession,
               !session.recordings.isEmpty {
                CompactButton(
                    title: "New",
                    icon: "plus.circle",
                    action: { viewModel.startNewSession() }
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

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let viewModel: AudioViewModel

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.audio],
            asCopy: true
        )
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let viewModel: AudioViewModel

        init(viewModel: AudioViewModel) {
            self.viewModel = viewModel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            viewModel.importAudio(from: url)
        }
    }
}

// MARK: - Preview

#Preview {
    MainViewPremium()
}
