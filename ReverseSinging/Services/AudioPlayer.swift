//
//  AudioPlayer.swift
//  ReverseSinging
//
//  Audio playback service with speed, pitch control, and looping
//  Uses AVAudioEngine for independent pitch/rate control
//

import AVFoundation
import Combine
import DubAudio

/// Why the player could not load or start.
enum AudioPlayerError: LocalizedError {
    /// The audio session could not be made active, most often because another app holds it.
    case sessionUnavailable(AudioSessionError)
    /// The session is active but the output has nowhere to go, so there is no format to build
    /// the engine's graph against.
    case noOutputRoute
    /// The file could not be read.
    case unreadableFile(Error)
    /// `AVAudioEngine` refused the graph, even after a rebuild. Carries what it raised.
    case graphRejected(String)

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable(let error): error.errorDescription
        case .noOutputRoute: Strings.Error.audioInUse
        case .unreadableFile(let error): error.localizedDescription
        case .graphRejected: Strings.Error.playbackUnavailable
        }
    }

    /// True when nothing in the app could have done better: the device is busy elsewhere.
    var isEnvironmental: Bool {
        switch self {
        case .sessionUnavailable(let error): error.isEnvironmental
        case .noOutputRoute: true
        case .unreadableFile, .graphRejected: false
        }
    }
}

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

    /// Set when the system rebuilt the engine under us (a route change, an interruption), so
    /// the next play reconnects the graph rather than trusting connections that are gone.
    private var needsReconnect = false

    /// Which scheduled buffer is the current one.
    ///
    /// A buffer scheduled with `.interrupts` still calls its completion handler when it is
    /// stopped or replaced, so without this a seek, a stop or a loop toggle had the old
    /// buffer's handler arrive a moment later and mark the new playback finished.
    private var playbackGeneration = 0

    /// How long to wait for the engine's first render cycle before starting a node at a
    /// host time. `play(at:)` on a node that has never rendered raises, and ended the
    /// process; a few milliseconds of patience is what it actually needed.
    private static let firstRenderTimeout: TimeInterval = 0.08

    override init() {
        super.init()
        setupAudioEngine()
        observeEngineChanges()
        // Audio session now managed centrally by AudioSessionManager
        // No need to configure here - prevents conflicts with recording
    }

    // No `deinit`: a released engine stops and lets go of its nodes by itself, and the
    // progress timer invalidates itself once `self` is gone. `cleanup()` is for tearing
    // everything down while the player is still alive.

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

    // MARK: - Engine Changes

    /// The engine posts a configuration change when the route or the session changes under
    /// it: headphones out, a call in. It stops itself, and its connections are not to be
    /// trusted afterwards. Both notifications arrive off the main thread.
    private func observeEngineChanges() {
        guard let engine = audioEngine else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc nonisolated private func handleConfigurationChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.needsReconnect = true
            self.isPlaying = false
            self.stopProgressTimer()
        }
    }

    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: value) == .began else { return }
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }

    // MARK: - Playback Control

    func loadAudio(from url: URL) throws {
        stop()

        // The graph is built against the output's format, and the output has none until the
        // session is active. Building it anyway is what `AVAudioEngine` answered with an
        // exception, and the app with a crash, every time a call or another app held the
        // hardware.
        do {
            try AudioSessionManager.shared.activate()
        } catch {
            throw AudioPlayerError.sessionUnavailable(error)
        }
        guard AudioSessionManager.shared.hasOutputRoute else { throw AudioPlayerError.noOutputRoute }

        // Load audio file
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw AudioPlayerError.unreadableFile(error)
        }

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
            do {
                try file.read(into: buffer)
            } catch {
                throw AudioPlayerError.unreadableFile(error)
            }
        }

        try connect(player, through: timePitch, in: engine, format: format)

        // Warm the engine now rather than on the first press. Loading happens while the user
        // is still reaching for the transport, so this is free time; doing it inside `play()`
        // is time the user hears as lag before the audio arrives.
        engine.prepare()
        if !engine.isRunning {
            try? engine.start()
        }
    }

    /// Connects `player -> timePitch -> main mixer` in the file's format.
    ///
    /// `connect` does not return errors, it raises. A graph the engine will not build, which
    /// happens when the mixer's own format is unusable, is tried once more over a stopped
    /// engine and then given up as a thrown error rather than a crash.
    private func connect(
        _ player: AVAudioPlayerNode,
        through timePitch: AVAudioUnitTimePitch,
        in engine: AVAudioEngine,
        format: AVAudioFormat
    ) throws {
        let wire = {
            // Disconnect first if already connected
            engine.disconnectNodeOutput(player)
            engine.disconnectNodeOutput(timePitch)
            engine.connect(player, to: timePitch, format: format)
            engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        }

        do {
            try AudioGraphGuard.attempt(wire)
        } catch {
            CrashReporter.shared.log("audio_player.connect raised, rebuilding: \(error)")
            if engine.isRunning { engine.stop() }
            engine.reset()
            do {
                try AudioGraphGuard.attempt(wire)
            } catch {
                throw AudioPlayerError.graphRejected(error.description)
            }
        }
        needsReconnect = false
    }

    /// Plays now, or on an exact future host-clock boundary when one is supplied.
    ///
    /// Scheduled playback is used by dub headphone monitoring so the reference, picture and
    /// microphone sample zero do not cue the performer at three slightly different times.
    func play(atHostTime hostTime: UInt64? = nil) {
        guard let engine = audioEngine,
              let player = playerNode,
              let buffer = audioBuffer else { return }

        if needsReconnect, let file = audioFile, let timePitch = timePitchNode {
            guard (try? connect(player, through: timePitch, in: engine, format: file.processingFormat)) != nil else {
                isPlaying = false
                return
            }
        }

        do {
            // Start engine if not running
            if !engine.isRunning {
                try engine.start()
            }

            schedule(buffer, on: player)

            guard start(player, in: engine, atHostTime: hostTime) else {
                isPlaying = false
                return
            }
            isPlaying = true
            startProgressTimer()
            HapticManager.shared.light()

        } catch {
            print("❌ Error starting audio engine: \(error)")
            isPlaying = false
        }
    }

    /// Starts `player`, at `hostTime` when the engine has rendered at least once and so can
    /// honour a deadline, immediately otherwise. False when the node would not start at all.
    ///
    /// Each `play` here can raise rather than return, so each runs behind `AudioGraphGuard`.
    @discardableResult
    private func start(_ player: AVAudioPlayerNode, in engine: AVAudioEngine, atHostTime hostTime: UInt64?) -> Bool {
        if let hostTime, Self.waitForFirstRender(of: engine) {
            if AudioGraphGuard.succeeds({ player.play(at: AVAudioTime(hostTime: hostTime)) }) { return true }
            CrashReporter.shared.log("audio_player.play(at:) raised; starting immediately")
        }
        if AudioGraphGuard.succeeds({ player.play() }) { return true }
        CrashReporter.shared.recordFailure("audio_player.play", reason: "player node refused to start")
        return false
    }

    /// True once the engine's output has rendered, or false after a short wait if it has not.
    private static func waitForFirstRender(of engine: AVAudioEngine) -> Bool {
        let deadline = Date().addingTimeInterval(firstRenderTimeout)
        while engine.outputNode.lastRenderTime?.isSampleTimeValid != true {
            if Date() >= deadline { return false }
            usleep(2_000)
        }
        return true
    }

    func pause() {
        playerNode?.pause()
        isPlaying = false
        stopProgressTimer()
        HapticManager.shared.light()
    }

    /// Stops playback, but leaves the engine running.
    ///
    /// Tearing the engine down here is what made every press of play feel late:
    /// `AVAudioEngine.start()` takes real time on a `.playAndRecord` session, and `loadAudio`
    /// stops before it loads. So the engine was cold on every single press. An idle engine
    /// costs almost nothing; it is torn down in `cleanup()`.
    func stop() {
        // Stopping the node fires the current buffer's completion; this playback is already
        // being ended here, so that late arrival must not end it a second time.
        playbackGeneration += 1
        playerNode?.stop()
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
    }

    func seek(to time: TimeInterval) {
        guard let player = playerNode,
              let engine = audioEngine,
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
            schedule(seekBuffer, on: player)

            currentTime = time

            // Resume playback if it was playing
            if wasPlaying, !start(player, in: engine, atHostTime: nil) {
                isPlaying = false
                stopProgressTimer()
            }
        }
    }

    /// Schedules `buffer` on `player`, looping or once, as the current playback.
    private func schedule(_ buffer: AVAudioPCMBuffer, on player: AVAudioPlayerNode) {
        playbackGeneration += 1

        if isLooping {
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            return
        }

        // Called on the engine's render thread, so the handler must not be main-actor
        // isolated; it only carries the generation back to the main actor.
        let generation = playbackGeneration
        let completion: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.handlePlaybackCompletion(generation: generation) }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: completion)
    }

    private func handlePlaybackCompletion(generation: Int) {
        guard generation == playbackGeneration, !isLooping else { return }

        isPlaying = false
        currentTime = 0
        stopProgressTimer()
        HapticManager.shared.light()
    }

    private func rescheduleWithLoopSetting() {
        // Only reschedule if currently playing
        guard isPlaying,
              let player = playerNode,
              let engine = audioEngine,
              let buffer = audioBuffer else { return }

        // Stop current playback (but don't stop engine)
        player.stop()

        // Reschedule buffer with new loop setting
        schedule(buffer, on: player)

        // Resume playback immediately
        if !start(player, in: engine, atHostTime: nil) {
            isPlaying = false
            stopProgressTimer()
        }
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
        // Playing while already playing would otherwise leave the previous timer running.
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            // Scheduled on the main run loop, so this always fires on the main thread.
            MainActor.assumeIsolated { self.updateProgress() }
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

        // `stop()` deliberately keeps the engine warm, so this is the one place that shuts
        // it down.
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
        }

        audioFile = nil
        audioBuffer = nil
    }
}
