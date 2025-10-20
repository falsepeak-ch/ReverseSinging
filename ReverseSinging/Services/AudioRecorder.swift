//
//  AudioRecorder.swift
//  ReverseSinging
//
//  Audio recording service
//

import AVFoundation
import Combine

final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private let audioFileManager = AudioFileManager.shared

    override init() {
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Recording

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func startRecording() throws -> URL {
        let url = audioFileManager.createTemporaryAudioURL()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        recordingDuration = 0

        startTimers()

        return url
    }

    func stopRecording() -> URL? {
        guard let recorder = audioRecorder else { return nil }

        recorder.stop()
        isRecording = false
        stopTimers()

        let url = recorder.url
        audioRecorder = nil

        return url
    }

    func cancelRecording() {
        guard let recorder = audioRecorder else { return }

        let url = recorder.url
        recorder.stop()
        isRecording = false
        stopTimers()

        audioRecorder = nil

        // Delete the temporary file
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Level Monitoring

    private func startTimers() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateLevel()
        }

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
        guard let recorder = audioRecorder else { return }

        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let normalizedLevel = max(0, (averagePower + 160) / 160)
        recordingLevel = normalizedLevel
    }

    private func updateDuration() {
        guard let recorder = audioRecorder else { return }
        recordingDuration = recorder.currentTime
    }

    // MARK: - Cleanup

    func cleanup() {
        _ = stopRecording()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        }
    }
}
