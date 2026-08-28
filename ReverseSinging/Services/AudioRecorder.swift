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
    /// Meter level, 0...1, on a decibel curve. Drives the pulsing record button and the
    /// level rails. A meter wants to move visibly at conversational volume, which is what
    /// the dB mapping in `updateLevel` gives it.
    @Published var recordingLevel: Float = 0

    /// Peak amplitude over the last metering interval, 0...1, **linear**.
    ///
    /// Deliberately a second, differently-shaped number. `recordingLevel` is average power on
    /// a dB curve, and a waveform drawn from it comes out as a tall flat block, every quiet
    /// syllable lifted to two thirds height by the dB compression. Where the very same take
    /// read back off disk by `WaveformSampler` is linear peaks against the file's own loudest
    /// moment: mostly short, with real spikes. The two disagreed so completely that the live
    /// trace visibly changed shape the instant recording stopped and the file was sampled.
    ///
    /// This is peak, and linear, so it is the same measurement the sampler makes.
    @Published var recordingPeak: Float = 0
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
    // Now using centralized AudioSessionManager to prevent conflicts

    private func activateAudioSession() throws {
        print("🎤 Activating audio session...")
        AudioSessionManager.shared.activate()
        print("✅ Audio session activated successfully")
    }

    private func deactivateAudioSession() {
        // Don't deactivate - keep session active for playback
        // AudioSessionManager.shared.deactivate()
        print("✅ Keeping audio session active for playback")
    }

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AudioSessionManager.shared.requestRecordPermission(completion: completion)
    }

    // MARK: - State Validation

    func canStartRecording() -> Bool {
        return lifecycleState == .idle && !isRecording
    }

    func canStopRecording() -> Bool {
        return lifecycleState == .recording && isRecording
    }

    // MARK: - Recording

    /// - Parameters:
    ///   - maxDuration: when set, the recorder stops itself after exactly this long. Handed to
    ///     `AVAudioRecorder` so the file ends on the audio clock rather than a UI timer.
    ///   - startDelay: scheduling runway before sample zero. Dub capture uses the same future
    ///     deadline for the recorder and the video, avoiding an asynchronous seek after the
    ///     microphone has already opened.
    ///   - onScheduled: receives the matching host-clock deadline after the recorder accepts
    ///     the schedule and before `isRecording` is published.
    func startRecording(
        maxDuration: TimeInterval? = nil,
        startDelay: TimeInterval = 0,
        onScheduled: ((UInt64) -> Void)? = nil
    ) throws -> URL {
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

        // Configure recording settings - use LinearPCM for compatibility with audio processing
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,  // Mono for voice
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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

            // Start recording. `record(atTime:)` is relative to the audio device clock and is
            // Apple's synchronization API; using it gives the picture enough runway to map
            // its first frame onto the same future instant.
            let success: Bool
            let delay = max(0, startDelay)
            var scheduledHostTime: UInt64?
            if delay > 0 {
                // Read both clocks together, after session activation and recorder setup.
                // Doing this earlier lets variable audio-session setup consume the runway.
                scheduledHostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay)
                let deviceStart = recorder.deviceCurrentTime + delay
                if let maxDuration, maxDuration > 0 {
                    success = recorder.record(atTime: deviceStart, forDuration: maxDuration)
                } else {
                    success = recorder.record(atTime: deviceStart)
                }
            } else if let maxDuration, maxDuration > 0 {
                success = recorder.record(forDuration: maxDuration)
            } else {
                success = recorder.record()
            }

            if success {
                if let scheduledHostTime { onScheduled?(scheduledHostTime) }
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
        recordingPeak = 0
    }

    private func updateLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            recordingLevel = 0
            recordingPeak = 0
            return
        }

        // One call feeds both numbers. The meters are only valid until the next update, and
        // sampling them twice would give the two readings different intervals.
        recorder.updateMeters()

        // The meter: average power, mapped across the range speech actually occupies, so the
        // rails and the record button move rather than sitting pinned at the bottom.
        let averagePower = recorder.averagePower(forChannel: 0)  // dB, typically -160...0
        let clampedDb = max(Self.meterFloorDb, min(Self.meterCeilingDb, averagePower))
        let normalizedLevel = (clampedDb - Self.meterFloorDb) / (Self.meterCeilingDb - Self.meterFloorDb)
        recordingLevel = max(0, min(1, normalizedLevel))

        // The waveform: peak, converted straight back to linear amplitude with no curve and
        // no floor. This is the number `WaveformSampler` reads off the finished file, which is
        // the whole reason it exists separately.
        recordingPeak = max(0, min(1, pow(10, recorder.peakPower(forChannel: 0) / 20)))
    }

    /// Quietest and loudest the *meter* stretches across. Speech runs roughly -40 dB at a
    /// murmur to -10 dB shouted, so this is the band worth spending the rail on.
    private static let meterFloorDb: Float = -50
    private static let meterCeilingDb: Float = -10

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
