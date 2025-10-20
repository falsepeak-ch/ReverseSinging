//
//  AudioRecorder.swift
//  ReverseSinging
//
//  Audio recording service with robust session management
//

import AVFoundation
import Combine

// MARK: - Recording Errors

enum RecordingError: LocalizedError {
    case permissionDenied
    case sessionActivationFailed(Error)
    case recorderInitializationFailed(Error)
    case alreadyRecording
    case notRecording
    case interruptedBySystem

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record audio. Please enable it in Settings."
        case .sessionActivationFailed(let error):
            return "Failed to activate audio session: \(error.localizedDescription)"
        case .recorderInitializationFailed(let error):
            return "Failed to initialize recorder: \(error.localizedDescription)"
        case .alreadyRecording:
            return "Already recording. Please stop the current recording first."
        case .notRecording:
            return "No recording in progress."
        case .interruptedBySystem:
            return "Recording was interrupted by the system."
        }
    }
}

// MARK: - Recording State

enum RecordingLifecycleState {
    case idle
    case preparing
    case recording
    case stopping
    case interrupted
}

// MARK: - Audio Recorder

final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingLevel: Float = 0
    @Published var lifecycleState: RecordingLifecycleState = .idle

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private let audioFileManager = AudioFileManager.shared
    private var wasInterrupted = false

    override init() {
        super.init()
        setupNotifications()
    }

    deinit {
        removeNotifications()
        cleanup()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Interruption Handling

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        print("📱 Audio interruption: \(type == .began ? "began" : "ended")")

        switch type {
        case .began:
            // Interruption began (phone call, alarm, etc.)
            if isRecording {
                print("⚠️ Recording interrupted by system")
                wasInterrupted = true
                lifecycleState = .interrupted
                // Stop recording gracefully
                _ = stopRecording()
            }

        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) {
                print("💡 Could resume recording, but letting user restart manually")
                wasInterrupted = false
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("🎧 Audio route changed: \(reason.rawValue)")

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged or bluetooth disconnected
            if isRecording {
                print("⚠️ Recording device disconnected")
                // Continue recording with built-in mic
            }
        default:
            break
        }
    }

    // MARK: - Audio Session Management

    private func activateAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        print("🎤 Activating audio session...")

        do {
            // Use .playAndRecord for recording, .allowBluetooth for better device support
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session activated successfully")
        } catch {
            print("❌ Failed to activate audio session: \(error)")
            throw RecordingError.sessionActivationFailed(error)
        }
    }

    private func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                print(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
                completion(granted)
            }
        }
    }

    // MARK: - State Validation

    func canStartRecording() -> Bool {
        return lifecycleState == .idle && !isRecording
    }

    func canStopRecording() -> Bool {
        return lifecycleState == .recording && isRecording
    }

    // MARK: - Recording

    func startRecording() throws -> URL {
        print("🎙️ Attempting to start recording...")

        // Validate state
        guard canStartRecording() else {
            print("❌ Cannot start recording - invalid state: \(lifecycleState)")
            throw RecordingError.alreadyRecording
        }

        lifecycleState = .preparing

        // Activate audio session
        do {
            try activateAudioSession()
        } catch {
            lifecycleState = .idle
            throw error
        }

        // Create recording URL
        let url = audioFileManager.createTemporaryAudioURL()

        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,  // Mono for voice
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000  // 128 kbps
        ]

        // Initialize recorder
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            guard let recorder = audioRecorder else {
                lifecycleState = .idle
                deactivateAudioSession()
                throw RecordingError.recorderInitializationFailed(
                    NSError(domain: "AudioRecorder", code: -1, userInfo: nil)
                )
            }

            // Start recording
            let success = recorder.record()

            if success {
                isRecording = true
                recordingDuration = 0
                lifecycleState = .recording
                startTimers()
                print("✅ Recording started successfully")
                return url
            } else {
                lifecycleState = .idle
                deactivateAudioSession()
                throw RecordingError.recorderInitializationFailed(
                    NSError(domain: "AudioRecorder", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to start recording"
                    ])
                )
            }
        } catch {
            lifecycleState = .idle
            deactivateAudioSession()
            print("❌ Failed to initialize recorder: \(error)")
            throw RecordingError.recorderInitializationFailed(error)
        }
    }

    func stopRecording() -> URL? {
        print("🛑 Attempting to stop recording...")

        guard let recorder = audioRecorder else {
            print("⚠️ No recorder instance to stop")
            lifecycleState = .idle
            return nil
        }

        lifecycleState = .stopping

        recorder.stop()
        isRecording = false
        stopTimers()

        let url = recorder.url
        audioRecorder = nil

        lifecycleState = .idle

        // Deactivate audio session to free resources
        deactivateAudioSession()

        print("✅ Recording stopped successfully")

        return url
    }

    func cancelRecording() {
        print("❌ Cancelling recording...")

        guard let recorder = audioRecorder else {
            lifecycleState = .idle
            return
        }

        let url = recorder.url
        recorder.stop()
        isRecording = false
        stopTimers()

        audioRecorder = nil
        lifecycleState = .idle

        // Deactivate audio session
        deactivateAudioSession()

        // Delete the temporary file
        try? FileManager.default.removeItem(at: url)

        print("✅ Recording cancelled")
    }

    // MARK: - Level Monitoring

    private func startTimers() {
        // Create level timer and add to .common RunLoop mode
        // This ensures it fires during UI updates and scrolling
        let levelTimerInstance = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateLevel()
        }
        RunLoop.main.add(levelTimerInstance, forMode: .common)
        levelTimer = levelTimerInstance
        print("🔊 Level timer started on .common RunLoop mode")

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate()
        durationTimer?.invalidate()
        levelTimer = nil
        durationTimer = nil
        recordingLevel = 0
    }

    private func updateLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            recordingLevel = 0
            return
        }

        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)  // dB value (typically -160 to 0)

        // Convert dB to 0-1 range with better normalization for speech
        // Speech typically ranges from -40 dB (quiet) to -10 dB (loud)
        // Map this to a visible range
        let minDb: Float = -50.0  // Noise floor
        let maxDb: Float = -10.0  // Loud speech
        let clampedDb = max(minDb, min(maxDb, averagePower))
        let normalizedLevel = (clampedDb - minDb) / (maxDb - minDb)

        recordingLevel = max(0, min(1, normalizedLevel))

        // Debug logging (only log every 10th sample to avoid spam)
        if Int(recorder.currentTime * 20) % 10 == 0 {
            print("🔊 Level: dB=\(String(format: "%.1f", averagePower)), normalized=\(String(format: "%.3f", recordingLevel))")
        }
    }

    private func updateDuration() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return
        }
        recordingDuration = recorder.currentTime
    }

    // MARK: - Cleanup

    func cleanup() {
        print("🧹 Cleaning up AudioRecorder...")
        stopTimers()
        if isRecording {
            cancelRecording()
        }
        deactivateAudioSession()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("✅ Recording finished successfully")
        } else {
            print("❌ Recording finished with error")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("❌ Recording encode error: \(error.localizedDescription)")
        }
    }
}
