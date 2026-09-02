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
    /// Beats left in the record slate, 3...1, or nil when no countdown is running.
    @Published private(set) var countdown: Int?

    @Published var isReversing = false
    @Published var showSessionList = false
    @Published var showSettings = false
    @Published var showDubLibrary = false

    /// Set when the system hands us a pack from AirDrop or "Open with"; the dub library
    /// picks it up and imports it.
    @Published var pendingDubImportURL: URL?

    // MARK: - Services

    private let recorder = AudioRecorder()
    private let player = AudioPlayer()
    private let reverser = AudioReverser.shared
    private let fileManager = AudioFileManager.shared

    // MARK: - Private Properties

    private var currentRecordingURL: URL?
    private let slate = RecordSlate()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
        loadSessions()
        checkPermissionStatus()
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

        player.$pitchShift
            .sink { [weak self] pitch in
                self?.appState.pitchShift = pitch
            }
            .store(in: &cancellables)
    }

    // MARK: - Permissions

    /// Check current microphone permission status
    func checkPermissionStatus() {
        hasRecordingPermission = AudioSessionManager.shared.hasRecordPermission
    }

    private func requestPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        recorder.requestPermission { [weak self] granted in
            self?.hasRecordingPermission = granted
            completion(granted)
        }
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        requestPermissionIfNeeded { granted in
            completion?(granted)
        }
    }

    // MARK: - Recording

    func startRecording() {
        print("🎬 StartRecording called from UI")

        // A second press during the slate is a change of mind, not a stop: nothing has been
        // recorded yet, so cancel the count rather than arming a second one behind it.
        if slate.isRunning {
            cancelCountdown()
            return
        }

        // Request permission if we haven't asked yet or need to re-check
        requestPermissionIfNeeded { [weak self] granted in
            guard let self = self else { return }

            guard granted else {
                print("⚠️ Microphone permission denied")
                self.errorMessage = Strings.Error.microphonePermissionRequired
                self.showPermissionAlert = true
                AnalyticsManager.shared.trackPermissionDenied()
                return
            }

            // Track permission granted
            AnalyticsManager.shared.trackPermissionGranted()

            // Validate recorder state
            guard self.recorder.canStartRecording() else {
                print("⚠️ Cannot start recording - recorder not ready")
                self.errorMessage = Strings.Error.cannotStartRecording
                return
            }

            // Create new session if needed
            if self.appState.currentSession == nil {
                self.appState.startNewSession()
            }

            self.runCountdownThenRecord()
        }
    }

    /// Slate, then roll: three tones, the mic opening as the last one releases.
    private func runCountdownThenRecord() {
        slate.run(
            onBeat: { [weak self] beat in self?.countdown = beat },
            thenRecord: { [weak self] in self?.beginRecording() }
        )
    }

    private func cancelCountdown() { slate.cancel() }

    private func beginRecording() {
        guard recorder.canStartRecording() else { return }

        do {
            SoundManager.shared.setMicrophoneOpen(true)
            let url = try recorder.startRecording()
            currentRecordingURL = url
            HapticManager.shared.heavy()
            print("✅ Recording started from ViewModel")

            // Determine recording type for analytics
            let recordingType = appState.currentSession?.reversedRecording != nil ? "attempt" : "original"
            AnalyticsManager.shared.trackRecordingStarted(type: recordingType)
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
            errorMessage = Strings.Error.noRecordingInProgress
            return
        }

        guard let url = recorder.stopRecording() else {
            print("❌ Failed to get recording URL")
            SoundManager.shared.setMicrophoneOpen(false)
            errorMessage = Strings.Error.failedToStopRecording
            return
        }

        SoundManager.shared.setMicrophoneOpen(false)
        SoundManager.shared.play(.tapeStop)
        HapticManager.shared.heavy()

        // Process file operations on background thread
        Task {
            do {
                // Get duration and save (runs on background thread)
                guard let duration = await fileManager.getAudioDurationAsync(from: url) else {
                    await MainActor.run {
                        print("❌ Failed to get audio duration")
                        self.errorMessage = Strings.Error.failedToProcessRecording
                    }
                    return
                }

                let savedURL = try await fileManager.saveRecordingAsync(from: url)
                let recording = Recording(url: savedURL, duration: duration, type: type)

                // Track recording completed
                AnalyticsManager.shared.trackRecordingCompleted(type: type.rawValue, duration: duration)

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

                    // Auto-reverse and calculate similarity if this was the attempt recording
                    if type == .attempt {
                        print("🔄 Auto-reversing attempt and calculating similarity...")
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                            self.reverseAttempt()
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
        SoundManager.shared.setMicrophoneOpen(false)
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

        // Track reversal started
        let startTime = Date()
        AnalyticsManager.shared.trackAudioReversalStarted()

        reverser.reverseAudio(inputURL: originalRecording.url) { [weak self] result in
            guard let self = self else { return }

            self.isReversing = false
            let processingTime = Date().timeIntervalSince(startTime)

            switch result {
            case .success(let reversedURL):
                // Track reversal completed
                AnalyticsManager.shared.trackAudioReversalCompleted(duration: processingTime)

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

                            SoundManager.shared.play(.projectorChime)
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
                // Track reversal failed
                AnalyticsManager.shared.trackAudioReversalFailed(error: error.localizedDescription)
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

            // Track playback started
            AnalyticsManager.shared.trackPlaybackStarted(recordingType: recording.type.rawValue)
        } catch {
            handleError(error)
        }
    }

    func stopPlayback() {
        player.stop()
    }

    func setPlaybackSpeed(_ speed: Double) {
        player.playbackSpeed = speed
        AnalyticsManager.shared.trackPlaybackSpeedChanged(speed: speed)
    }

    func toggleLooping() {
        player.isLooping.toggle()
        AnalyticsManager.shared.trackPlaybackLoopToggled(enabled: player.isLooping)
    }

    func setPitchShift(_ pitch: Float) {
        player.pitchShift = pitch
        let semitones = Int(round(pitch / 100.0))
        AnalyticsManager.shared.trackPlaybackPitchChanged(semitones: semitones)
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
        let recordingsCount = appState.currentSession?.recordings.count ?? 0
        let score = appState.similarityScore

        appState.saveCurrentSession()
        saveSessions()
        HapticManager.shared.success()

        // Track session saved
        AnalyticsManager.shared.trackSessionSaved(recordingsCount: recordingsCount)
        if let score = score {
            AnalyticsManager.shared.trackSessionCompleted(score: score)
        }

        // Same gate as the app-open ask, so the two triggers share one throttle
        // rather than competing for Apple's three prompts a year.
        ReviewPrompt.shared.requestIfAppropriate(trigger: "session_saved")
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
            AnalyticsManager.shared.trackNewSessionFromExisting()
        }

        appState.startNewSession()
        player.stop()
        HapticManager.shared.medium()

        // Track new session started
        AnalyticsManager.shared.trackSessionStarted()
    }

    // MARK: - Persistence

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(appState.savedSessions) {
            UserDefaults.standard.set(encoded, forKey: "savedSessions")
        }

        UserDefaults.standard.set(appState.hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(appState.isScoreVisible, forKey: "isScoreVisible")
        UserDefaults.standard.set(appState.themeMode.rawValue, forKey: "themeMode")
        UserDefaults.standard.set(appState.hapticsEnabled, forKey: "hapticsEnabled")
    }

    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "savedSessions"),
           let sessions = try? JSONDecoder().decode([AudioSession].self, from: data) {
            appState.savedSessions = sessions
        }

        appState.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // Load isScoreVisible with default true if key doesn't exist
        if UserDefaults.standard.object(forKey: "isScoreVisible") != nil {
            appState.isScoreVisible = UserDefaults.standard.bool(forKey: "isScoreVisible")
        } else {
            appState.isScoreVisible = true  // Default to visible on first launch
        }

        // Load theme mode with default system if key doesn't exist
        if let themeModeString = UserDefaults.standard.string(forKey: "themeMode"),
           let themeMode = ThemeMode(rawValue: themeModeString) {
            appState.themeMode = themeMode
        } else {
            appState.themeMode = .system  // Default to system on first launch
        }

        // Load haptics enabled with default true if key doesn't exist
        if UserDefaults.standard.object(forKey: "hapticsEnabled") != nil {
            appState.hapticsEnabled = UserDefaults.standard.bool(forKey: "hapticsEnabled")
        } else {
            appState.hapticsEnabled = true  // Default to enabled on first launch
        }

        // Load UI mode with default simple if key doesn't exist
        if let uiModeString = UserDefaults.standard.string(forKey: "uiMode"),
           let uiMode = UIMode(rawValue: uiModeString) {
            appState.uiMode = uiMode
        } else {
            appState.uiMode = .simple  // Default to simple on first launch
        }
    }

    func completeOnboarding() {
        appState.hasCompletedOnboarding = true
        saveSessions()
    }

    #if DEBUG
    /// Every `UserDefaults` key `loadSessions()` reads back into `appState`.
    ///
    /// Kept next to the code that writes them so the two cannot drift: a key added to
    /// `saveSessions` and forgotten here would silently reintroduce the problem below.
    static let persistedStateKeysForTesting = [
        "savedSessions",
        "hasCompletedOnboarding",
        "isScoreVisible",
        "themeMode",
        "hapticsEnabled",
        "uiMode",
    ]

    /// Puts the device back to the state of one the app has never been run on.
    ///
    /// `AudioViewModel()` loads its whole `appState` from `UserDefaults`, so any test that
    /// constructs one is really asserting about the simulator, not about the view model. The
    /// suite used to *assume* a clean device, `completeOnboarding()` asserted
    /// `!hasCompletedOnboarding` on a fresh instance. Which held right up until someone ran
    /// the app on the same simulator, and then failed until it was uninstalled. Establishing
    /// the state is the fix; assuming it is the bug.
    static func resetPersistedStateForTesting() {
        for key in persistedStateKeysForTesting {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    #endif

    // MARK: - Settings

    func setSoundsEnabled(_ enabled: Bool) {
        objectWillChange.send()
        SoundManager.shared.setEnabled(enabled)
        AnalyticsManager.shared.trackCustomEvent(name: "sounds_changed", parameters: ["enabled": enabled])
    }

    var soundsEnabled: Bool { SoundManager.shared.isEnabled }

    func setHapticsEnabled(_ enabled: Bool) {
        objectWillChange.send()
        appState.hapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "hapticsEnabled")
        AnalyticsManager.shared.trackCustomEvent(name: "haptics_changed", parameters: ["enabled": enabled])
    }

    func setUIMode(_ mode: UIMode) {
        objectWillChange.send()
        appState.uiMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "uiMode")
        AnalyticsManager.shared.trackCustomEvent(name: "ui_mode_changed", parameters: ["mode": mode.rawValue])
    }

    // MARK: - Error Handling

    private func handleRecordingError(_ error: RecordingError) {
        print("❌ Recording error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        appState.recordingState = .error(error.localizedDescription)
        HapticManager.shared.error()

        // Show permission alert if permission was denied
        if case .permissionDenied = error {
            showPermissionAlert = true
            // A denied microphone is the user's choice, not a fault. Reporting it would
            // bury the recorder failures that are.
            return
        }

        CrashReporter.shared.record(error, context: "reverse.record")
    }

    /// Every failure the reverse-singing mode shows the user passes through here, so this
    /// is the one place that has to report for the whole mode.
    private func handleError(_ error: Error) {
        print("❌ Error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        appState.recordingState = .error(error.localizedDescription)
        SoundManager.shared.play(.errorThunk)
        HapticManager.shared.error()

        CrashReporter.shared.record(error, context: "reverse.session")
    }

    // MARK: - Cleanup

    func cleanup() {
        cancelCountdown()
        recorder.cleanup()
        player.cleanup()
        fileManager.deleteAllTemporaryFiles()
    }
}
