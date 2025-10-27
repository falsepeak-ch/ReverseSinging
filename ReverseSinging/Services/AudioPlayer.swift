//
//  AudioPlayer.swift
//  ReverseSinging
//
//  Audio playback service with speed, pitch control, and looping
//  Uses AVAudioEngine for independent pitch/rate control
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
    @Published var pitchShift: Float = 0.0 {
        didSet { updatePitch() }
    }
    @Published var isLooping = false {
        didSet { rescheduleWithLoopSetting() }
    }

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var timePitchNode: AVAudioUnitTimePitch?
    private var audioFile: AVAudioFile?
    private var progressTimer: Timer?
    private var audioBuffer: AVAudioPCMBuffer?
    private var isScheduledToLoop = false

    override init() {
        super.init()
        setupAudioEngine()
        // Audio session now managed centrally by AudioSessionManager
        // No need to configure here - prevents conflicts with recording
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        timePitchNode = AVAudioUnitTimePitch()

        guard let engine = audioEngine,
              let player = playerNode,
              let timePitch = timePitchNode else { return }

        // Attach nodes (don't connect yet - wait for audio file format)
        engine.attach(player)
        engine.attach(timePitch)

        // Initial settings
        timePitch.rate = Float(playbackSpeed)
        timePitch.pitch = pitchShift
    }

    // MARK: - Playback Control

    func loadAudio(from url: URL) throws {
        stop()

        // Load audio file
        audioFile = try AVAudioFile(forReading: url)

        guard let file = audioFile,
              let engine = audioEngine,
              let player = playerNode,
              let timePitch = timePitchNode else {
            throw NSError(domain: "AudioPlayer", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load audio file"
            ])
        }

        let format = file.processingFormat

        // Calculate duration
        let frameCount = file.length
        let sampleRate = format.sampleRate
        duration = Double(frameCount) / sampleRate
        currentTime = 0

        // Load entire file into buffer for looping support
        audioBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        )

        if let buffer = audioBuffer {
            try file.read(into: buffer)
        }

        // Connect nodes with the audio file's format
        // Disconnect first if already connected
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(timePitch)

        // Connect: playerNode -> timePitch -> mainMixerNode using file format
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
    }

    func play() {
        guard let engine = audioEngine,
              let player = playerNode,
              let buffer = audioBuffer else { return }

        do {
            // Start engine if not running
            if !engine.isRunning {
                try engine.start()
            }

            // Schedule buffer
            if isLooping {
                // Schedule with looping
                player.scheduleBuffer(buffer, at: nil, options: .loops)
            } else {
                // Schedule once with completion handler
                player.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak self] in
                    DispatchQueue.main.async {
                        self?.handlePlaybackCompletion()
                    }
                }
            }

            player.play()
            isPlaying = true
            startProgressTimer()
            HapticManager.shared.light()

        } catch {
            print("❌ Error starting audio engine: \(error)")
            isPlaying = false
        }
    }

    func pause() {
        playerNode?.pause()
        isPlaying = false
        stopProgressTimer()
        HapticManager.shared.light()
    }

    func stop() {
        playerNode?.stop()
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
        }
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
    }

    func seek(to time: TimeInterval) {
        guard let player = playerNode,
              let file = audioFile,
              let buffer = audioBuffer else { return }

        let wasPlaying = isPlaying

        // Stop current playback
        player.stop()

        // Calculate frame position
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)

        // Create buffer from seek position
        guard startFrame < file.length else { return }

        let frameCount = file.length - startFrame
        let seekBuffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        )

        if let seekBuffer = seekBuffer,
           let originalData = buffer.floatChannelData {
            // Copy audio data from seek position
            let seekData = seekBuffer.floatChannelData
            let channelCount = Int(file.processingFormat.channelCount)

            for channel in 0..<channelCount {
                let source = originalData[channel].advanced(by: Int(startFrame))
                let destination = seekData?[channel]
                destination?.update(from: source, count: Int(frameCount))
            }

            seekBuffer.frameLength = AVAudioFrameCount(frameCount)

            // Schedule new buffer
            if isLooping {
                player.scheduleBuffer(seekBuffer, at: nil, options: .loops)
            } else {
                player.scheduleBuffer(seekBuffer, at: nil, options: .interrupts) { [weak self] in
                    DispatchQueue.main.async {
                        self?.handlePlaybackCompletion()
                    }
                }
            }

            currentTime = time

            // Resume playback if it was playing
            if wasPlaying {
                player.play()
            }
        }
    }

    private func handlePlaybackCompletion() {
        if !isLooping {
            isPlaying = false
            currentTime = 0
            stopProgressTimer()
            HapticManager.shared.light()
        }
    }

    private func rescheduleWithLoopSetting() {
        // Only reschedule if currently playing
        guard isPlaying,
              let player = playerNode,
              let buffer = audioBuffer else { return }

        // Stop current playback (but don't stop engine)
        player.stop()

        // Reschedule buffer with new loop setting
        if isLooping {
            // Schedule with looping
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        } else {
            // Schedule once with completion handler
            player.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak self] in
                DispatchQueue.main.async {
                    self?.handlePlaybackCompletion()
                }
            }
        }

        // Resume playback immediately
        player.play()
    }

    // MARK: - Speed and Pitch Control

    private func updatePlaybackRate() {
        timePitchNode?.rate = Float(playbackSpeed)
    }

    private func updatePitch() {
        timePitchNode?.pitch = pitchShift
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
        guard let player = playerNode,
              let lastRenderTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: lastRenderTime),
              let file = audioFile else { return }

        let sampleRate = file.processingFormat.sampleRate
        let elapsedTime = Double(playerTime.sampleTime) / sampleRate

        // Adjust for playback rate
        currentTime = elapsedTime / playbackSpeed

        // Clamp to duration
        if currentTime > duration {
            currentTime = duration
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        stop()

        // Disconnect nodes before stopping
        if let engine = audioEngine, let player = playerNode, let timePitch = timePitchNode {
            engine.disconnectNodeOutput(player)
            engine.disconnectNodeOutput(timePitch)
        }

        audioFile = nil
        audioBuffer = nil
    }

    deinit {
        cleanup()
    }
}
