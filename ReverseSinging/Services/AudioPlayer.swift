//
//  AudioPlayer.swift
//  ReverseSinging
//
//  Audio playback service with speed control and looping
//

import AVFoundation
import Combine

final class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Double = 1.0 {
        didSet { updatePlaybackRate() }
    }
    @Published var isLooping = false

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    override init() {
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Playback Control

    func loadAudio(from url: URL) throws {
        stop()

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.enableRate = true
        audioPlayer?.rate = Float(playbackSpeed)

        duration = audioPlayer?.duration ?? 0
        currentTime = 0
    }

    func play() {
        guard let player = audioPlayer else { return }

        if isLooping {
            player.numberOfLoops = -1
        } else {
            player.numberOfLoops = 0
        }

        player.play()
        isPlaying = true
        startProgressTimer()
        HapticManager.shared.light()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
        HapticManager.shared.light()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    // MARK: - Speed Control

    private func updatePlaybackRate() {
        guard let player = audioPlayer else { return }
        player.rate = Float(playbackSpeed)
    }

    // MARK: - Progress Monitoring

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
    }

    // MARK: - Cleanup

    func cleanup() {
        stop()
        audioPlayer = nil
    }

    deinit {
        cleanup()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !isLooping {
            isPlaying = false
            currentTime = 0
            stopProgressTimer()
            HapticManager.shared.light()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Playback error: \(error)")
        }
        isPlaying = false
        stopProgressTimer()
    }
}
