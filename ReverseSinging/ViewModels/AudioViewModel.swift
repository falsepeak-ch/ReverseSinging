//
//  AudioViewModel.swift
//  ReverseSinging
//
//  Main view model coordinating audio services
//

import SwiftUI
import Combine

@MainActor
final class AudioViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var appState = AppState()
    @Published var hasRecordingPermission = false
    @Published var showPermissionAlert = false
    @Published var errorMessage: String?

    // Audio levels and progress
    @Published var recordingLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var playbackDuration: Double = 0

    // UI state
    @Published var isReversing = false
    @Published var showSessionList = false

    // MARK: - Services

    private let recorder = AudioRecorder()
    private let player = AudioPlayer()
    private let reverser = AudioReverser.shared
    private let fileManager = AudioFileManager.shared

    // MARK: - Private Properties

    private var currentRecordingURL: URL?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
        checkPermissions()
        loadSessions()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Recorder bindings
        recorder.$recordingLevel
            .sink { [weak self] level in
                self?.recordingLevel = level
                // Debug: Log level changes (sample every 10th update)
                if Int(Date().timeIntervalSince1970 * 20) % 10 == 0 {
                    print("📊 ViewModel received level: \(String(format: "%.3f", level))")
                }
            }
            .store(in: &cancellables)

        recorder.$recordingDuration
            .assign(to: &$recordingDuration)

        recorder.$isRecording
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                if isRecording {
                    self.appState.recordingState = .recording
                } else if case .recording = self.appState.recordingState {
                    self.appState.recordingState = .idle
                }
            }
            .store(in: &cancellables)

        // Player bindings
        player.$currentTime
            .assign(to: &$playbackProgress)

        player.$duration
            .assign(to: &$playbackDuration)

        player.$isPlaying
            .sink { [weak self] isPlaying in
                guard let self = self else { return }
                if isPlaying {
                    self.appState.recordingState = .playing
                } else if case .playing = self.appState.recordingState {
                    self.appState.recordingState = .idle
                }
            }
            .store(in: &cancellables)

        player.$playbackSpeed
            .sink { [weak self] speed in
                self?.appState.playbackSpeed = speed
            }
            .store(in: &cancellables)

        player.$isLooping
            .sink { [weak self] isLooping in
                self?.appState.isLooping = isLooping
            }
            .store(in: &cancellables)
    }

    // MARK: - Permissions

    private func checkPermissions() {
        recorder.requestPermission { [weak self] granted in
            self?.hasRecordingPermission = granted
            if !granted {
                self?.showPermissionAlert = true
            }
        }
    }

    func requestPermission() {
        checkPermissions()
    }

    // MARK: - Recording

    func startRecording() {
        print("🎬 StartRecording called from UI")

        // Re-check permissions before each recording (user may revoke in Settings)
        guard hasRecordingPermission else {
            print("⚠️ No microphone permission")
            errorMessage = "Microphone permission is required. Please enable it in Settings."
            showPermissionAlert = true
            return
        }

        // Validate recorder state
        guard recorder.canStartRecording() else {
            print("⚠️ Cannot start recording - recorder not ready")
            errorMessage = "Cannot start recording right now. Please try again."
            return
        }

        // Create new session if needed
        if appState.currentSession == nil {
            appState.startNewSession()
        }

        do {
            let url = try recorder.startRecording()
            currentRecordingURL = url
            HapticManager.shared.heavy()
            print("✅ Recording started from ViewModel")
        } catch let error as RecordingError {
            handleRecordingError(error)
        } catch {
            handleError(error)
        }
    }

    func stopRecording(type: Recording.RecordingType = .original) {
        print("⏹️ StopRecording called from UI (type: \(type.rawValue))")

        // Validate recorder state
        guard recorder.canStopRecording() else {
            print("⚠️ Cannot stop recording - not currently recording")
            errorMessage = "No recording in progress."
            return
        }

        guard let url = recorder.stopRecording() else {
            print("❌ Failed to get recording URL")
            errorMessage = "Failed to stop recording properly."
            return
        }

        HapticManager.shared.heavy()

        // Process file operations on background thread
        Task {
            do {
                // Get duration and save (runs on background thread)
                guard let duration = await fileManager.getAudioDurationAsync(from: url) else {
                    await MainActor.run {
                        print("❌ Failed to get audio duration")
                        self.errorMessage = "Failed to process recording."
                    }
                    return
                }

                let savedURL = try await fileManager.saveRecordingAsync(from: url)
                let recording = Recording(url: savedURL, duration: duration, type: type)

                // Update UI on main thread
                await MainActor.run {
                    // Explicitly reassign session to trigger @Published
                    if var session = self.appState.currentSession {
                        session.addRecording(recording)
                        self.appState.currentSession = session
                    }

                    print("✅ Recording saved: \(type.rawValue), duration: \(duration)s")

                    // Auto-reverse if this was the original recording
                    if type == .original {
                        print("🔄 Auto-reversing original recording...")
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                            self.reverseCurrentRecording()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to save recording: \(error)")
                    self.handleError(error)
                }
            }
        }

        currentRecordingURL = nil
    }

    func cancelRecording() {
        print("🚫 CancelRecording called")
        recorder.cancelRecording()
        currentRecordingURL = nil
        HapticManager.shared.light()
    }

    // MARK: - Reversal

    func reverseCurrentRecording() {
        guard let session = appState.currentSession,
              let originalRecording = session.originalRecording else {
            return
        }

        isReversing = true
        appState.recordingState = .reversing

        reverser.reverseAudio(inputURL: originalRecording.url) { [weak self] result in
            guard let self = self else { return }

            self.isReversing = false

            switch result {
            case .success(let reversedURL):
                // Move file operations to background thread
                Task {
                    do {
                        guard let duration = await self.fileManager.getAudioDurationAsync(from: reversedURL) else {
                            await MainActor.run {
                                self.appState.recordingState = .idle
                            }
                            return
                        }

                        let savedURL = try await self.fileManager.saveRecordingAsync(from: reversedURL)
                        let recording = Recording(url: savedURL, duration: duration, type: .reversed)

                        // Update UI on main thread
                        await MainActor.run {
                            // Explicitly reassign session to trigger @Published
                            if var session = self.appState.currentSession {
                                session.addRecording(recording)
                                self.appState.currentSession = session
                            }

                            HapticManager.shared.success()
                            self.appState.recordingState = .idle
                        }
                    } catch {
                        await MainActor.run {
                            self.handleError(error)
                            self.appState.recordingState = .idle
                        }
                    }
                }

            case .failure(let error):
                self.handleError(error)
                self.appState.recordingState = .idle
            }
        }
    }

    func reverseAttempt() {
        guard let session = appState.currentSession,
              let attemptRecording = session.attemptRecording,
              let originalRecording = session.originalRecording else {
            return
        }

        print("🔄 Reversing attempt and calculating similarity...")

        isReversing = true
        appState.recordingState = .reversing

        reverser.reverseAudio(inputURL: attemptRecording.url) { [weak self] result in
            guard let self = self else { return }

            self.isReversing = false

            switch result {
            case .success(let reversedURL):
                // Move file operations to background thread
                Task {
                    do {
                        guard let duration = await self.fileManager.getAudioDurationAsync(from: reversedURL) else {
                            await MainActor.run {
                                self.appState.recordingState = .idle
                            }
                            return
                        }

                        let savedURL = try await self.fileManager.saveRecordingAsync(from: reversedURL)
                        let recording = Recording(url: savedURL, duration: duration, type: .reversedAttempt)

                        // Update UI on main thread
                        await MainActor.run {
                            // Explicitly reassign session to trigger @Published
                            if var session = self.appState.currentSession {
                                session.addRecording(recording)
                                self.appState.currentSession = session
                            }

                            // Load for playback
                            try? self.player.loadAudio(from: savedURL)
                        }

                        // Calculate similarity score on background thread
                        let score = await AudioSimilarityCalculator.shared.calculateSimilarity(
                            original: originalRecording.url,
                            comparison: savedURL
                        )

                        await MainActor.run {
                            self.appState.similarityScore = score
                            self.appState.incrementAttemptCount()
                            print("✅ Similarity score: \(String(format: "%.1f", score))%")

                            // Celebrate if score is good
                            if score > 70 {
                                HapticManager.shared.success()
                            } else {
                                HapticManager.shared.medium()
                            }

                            self.appState.recordingState = .idle
                        }
                    } catch {
                        await MainActor.run {
                            self.handleError(error)
                            self.appState.recordingState = .idle
                        }
                    }
                }

            case .failure(let error):
                self.handleError(error)
                self.appState.recordingState = .idle
            }
        }
    }

    // MARK: - Playback

    func playRecording(_ recording: Recording) {
        do {
            try player.loadAudio(from: recording.url)
            player.play()
        } catch {
            handleError(error)
        }
    }

    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func stopPlayback() {
        player.stop()
    }

    func setPlaybackSpeed(_ speed: Double) {
        player.playbackSpeed = speed
    }

    func toggleLooping() {
        player.isLooping.toggle()
    }

    // MARK: - Game Flow

    func incrementPracticeListens() {
        appState.incrementPracticeListens()
        print("🎧 Practice listen count: \(appState.practiceListenCount)")
    }

    func reRecordAttempt() {
        print("🔁 Re-recording attempt (removing previous attempt)")
        appState.resetAttempt()
        player.stop()
        HapticManager.shared.medium()
    }

    // Removed goBackOneStep() - no longer using step-based navigation
    // Removed autoPlayReversedAudio() - user manually plays recordings now

    // MARK: - Session Management

    func saveSession() {
        appState.saveCurrentSession()
        saveSessions()
        HapticManager.shared.success()
    }

    func deleteSession(_ session: AudioSession) {
        // Delete all recordings
        for recording in session.recordings {
            try? fileManager.deleteRecording(at: recording.url)
        }

        appState.deleteSession(session)
        saveSessions()
        HapticManager.shared.light()
    }

    func startNewSession() {
        // Save current session if it has recordings
        if let currentSession = appState.currentSession,
           !currentSession.recordings.isEmpty {
            saveSession()
        }

        appState.startNewSession()
        player.stop()
        HapticManager.shared.medium()
    }

    func importAudio(from url: URL) {
        do {
            // Create new session if needed
            if appState.currentSession == nil {
                appState.startNewSession()
            }

            let savedURL = try fileManager.saveRecording(from: url)

            if let duration = fileManager.getAudioDuration(from: savedURL) {
                let recording = Recording(url: savedURL, duration: duration, type: .imported)
                appState.currentSession?.addRecording(recording)
                HapticManager.shared.success()
            }
        } catch {
            handleError(error)
        }
    }

    // MARK: - Persistence

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(appState.savedSessions) {
            UserDefaults.standard.set(encoded, forKey: "savedSessions")
        }

        UserDefaults.standard.set(appState.hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
    }

    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "savedSessions"),
           let sessions = try? JSONDecoder().decode([AudioSession].self, from: data) {
            appState.savedSessions = sessions
        }

        appState.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        appState.hasCompletedOnboarding = true
        saveSessions()
    }

    // MARK: - Error Handling

    private func handleRecordingError(_ error: RecordingError) {
        print("❌ Recording error: \(error.localizedDescription ?? "Unknown error")")
        errorMessage = error.localizedDescription
        appState.recordingState = .error(error.localizedDescription ?? "Recording failed")
        HapticManager.shared.error()

        // Show permission alert if permission was denied
        if case .permissionDenied = error {
            showPermissionAlert = true
        }
    }

    private func handleError(_ error: Error) {
        print("❌ Error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        appState.recordingState = .error(error.localizedDescription)
        HapticManager.shared.error()
    }

    // MARK: - Cleanup

    func cleanup() {
        recorder.cleanup()
        player.cleanup()
        fileManager.deleteAllTemporaryFiles()
    }
}
