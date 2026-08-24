//
//  DubPlayer.swift
//  ReverseSinging
//
//  Timeline playback of a dub pack: backing track plus one voice per line
//

import AVFoundation
import Combine

/// Which voice track plays over the backing track.
enum DubPlaybackMode: String, CaseIterable {
    case original   // the pack's reference dialogue
    case myDub      // the user's takes, falling back to the reference for un-recorded lines

    var displayName: String {
        switch self {
        case .original: return Strings.Dub.original
        case .myDub: return Strings.Dub.myDub
        }
    }
}

/// Plays a whole scene by scheduling every line at its `startTime`.
///
/// `AudioPlayer` stays the single-file player used elsewhere in the app; this is a separate
/// engine because a dub needs two tracks running against one clock.
@MainActor
final class DubPlayer: ObservableObject {

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isPreparing = false

    private let engine = AVAudioEngine()
    private let backingNode = AVAudioPlayerNode()

    /// One player node per overlapping voice, rebuilt whenever a pack is prepared.
    /// See `DubVoiceLanes` for why a single node cannot carry the whole scene.
    private var voiceNodes: [AVAudioPlayerNode] = []
    private var voiceLanes: [[DubLine]] = []

    private var backingBuffer: AVAudioPCMBuffer?
    private var backingFormat: AVAudioFormat?
    private var progressTimer: Timer?

    /// Line buffers keyed by slug, cached so a replay doesn't re-read the whole scene.
    ///
    /// Only ever valid for `loadedMode`: the two modes key on the same slugs but read from
    /// different files, so a cache shared between them hands Original's references back to My
    /// Dub and you listen to the film instead of your own take.
    private var voiceBuffers: [String: AVAudioPCMBuffer] = [:]
    private var loadedMode: DubPlaybackMode?

    /// Where each line's voice is actually dropped on the timeline, keyed by slug.
    ///
    /// Not simply `line.startTime`: a pack's timestamp is where the audio chunk begins, and a
    /// chunk usually opens with a beat of room tone. A take is aligned to where the original
    /// speaks instead. See `DubSpeechOnset`.
    private var voicePlacements: [String: TimeInterval] = [:]

    private var pack: DubPack?
    private var mode: DubPlaybackMode = .original
    private var playbackStartOffset: TimeInterval = 0
    private var wallClockAnchor: Date?

    /// Backing track sits under the voices rather than competing with them.
    private static let backingGain: Float = 0.75

    init() {
        engine.attach(backingNode)

        // Once, at the top of the graph. Voice lanes are rebuilt per pack but they all feed
        // the main mixer, so the limiter behind it never has to be rewired.
        DubMasterLimiter.install(in: engine)
    }

    deinit {
        progressTimer?.invalidate()
    }

    // MARK: - Loading

    /// Reads the backing track and every voice buffer the chosen mode needs.
    /// Safe to call repeatedly — already-loaded buffers are reused.
    func prepare(pack: DubPack, mode: DubPlaybackMode) async {
        isPreparing = true
        defer { isPreparing = false }

        self.pack = pack
        self.mode = mode
        duration = pack.duration

        let backingURL = pack.backingTrackURL
        let sources = voiceSources(for: pack, mode: mode)
        let alreadyLoaded = loadedMode == mode ? voiceBuffers : [:]

        let loaded: (AVAudioPCMBuffer?, [String: AVAudioPCMBuffer]) = await Task.detached(priority: .userInitiated) {
            var backing: AVAudioPCMBuffer?
            if let backingURL {
                backing = try? DubAudioLoader.loadBuffer(from: backingURL)
            }

            var voices: [String: AVAudioPCMBuffer] = [:]
            for (slug, url) in sources {
                if let cached = alreadyLoaded[slug] {
                    voices[slug] = cached
                    continue
                }
                voices[slug] = try? DubAudioLoader.loadVoiceBuffer(from: url)
            }

            return (backing, voices)
        }.value

        backingBuffer = loaded.0
        backingFormat = loaded.0?.format
        voiceBuffers = loaded.1
        loadedMode = mode

        alignVoices(for: pack, mode: mode)

        // Only lines that actually have audio take up a lane.
        voiceLanes = DubVoiceLanes.assign(
            pack.lines.filter { voiceBuffers[$0.slug] != nil },
            start: { self.placement(of: $0) },
            end: { line in
                guard let buffer = self.voiceBuffers[line.slug] else { return line.endTime }
                return self.placement(of: line)
                    + Double(buffer.frameLength) / DubAudioLoader.canonicalFormat.sampleRate
            }
        )

        connectNodes()
    }

    /// Which audio file supplies each line's voice in this mode. In `.myDub`, a line the
    /// user hasn't recorded falls back to the reference so the scene still plays end to end.
    private func voiceSources(for pack: DubPack, mode: DubPlaybackMode) -> [(String, URL)] {
        pack.lines.map { line in
            switch mode {
            case .original:
                return (line.slug, pack.referenceAudioURL(for: line))
            case .myDub:
                let take = pack.takeURL(for: line)
                let url = FileManager.default.fileExists(atPath: take.path)
                    ? take
                    : pack.referenceAudioURL(for: line)
                return (line.slug, url)
            }
        }
    }

    /// Trims each take's run-up and notes where its first word belongs.
    ///
    /// Only in `.myDub`: the reference already sits where it was cut from, so shifting it
    /// against itself would be a no-op at best. A line the user hasn't recorded plays its
    /// reference and is left alone for the same reason.
    private func alignVoices(for pack: DubPack, mode: DubPlaybackMode) {
        voicePlacements = [:]
        guard mode == .myDub else { return }

        for line in pack.lines {
            let takeURL = pack.takeURL(for: line)
            guard FileManager.default.fileExists(atPath: takeURL.path),
                  let take = voiceBuffers[line.slug] else { continue }

            let reference = try? DubAudioLoader.loadVoiceBuffer(
                from: pack.referenceAudioURL(for: line),
                applyFades: false
            )
            let referenceLead = reference.map(DubSpeechOnset.leadIn) ?? 0
            let takeLead = DubSpeechOnset.leadIn(of: take)

            if let aligned = DubAudioLoader.trimming(take, fromOffset: takeLead) {
                voiceBuffers[line.slug] = aligned
            }
            voicePlacements[line.slug] = line.startTime + referenceLead
        }
    }

    private func placement(of line: DubLine) -> TimeInterval {
        voicePlacements[line.slug] ?? line.startTime
    }

    private func connectNodes() {
        engine.disconnectNodeOutput(backingNode)

        // The backing node keeps the file's own format; the voice nodes always get the
        // canonical one, which is why every line buffer is converted at load.
        if let backingFormat {
            engine.connect(backingNode, to: engine.mainMixerNode, format: backingFormat)
        }
        backingNode.volume = Self.backingGain

        rebuildVoiceNodes(count: voiceLanes.count)
    }

    /// Tears down the previous pack's voice nodes and builds one per lane.
    ///
    /// Always runs with the engine stopped: `prepare` is only reached through `stopEverything`,
    /// and detaching a node from a running engine is not something to rely on.
    private func rebuildVoiceNodes(count: Int) {
        for node in voiceNodes {
            node.stop()
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }

        voiceNodes = (0..<max(0, count)).map { _ in
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: DubAudioLoader.canonicalFormat)
            node.volume = 1.0
            return node
        }
    }

    /// Drops a line's cached voice, so a take that has just been re-recorded is read again
    /// rather than played back as the one it replaced.
    func invalidateVoice(for line: DubLine) {
        voiceBuffers[line.slug] = nil
        voicePlacements[line.slug] = nil
    }

    #if DEBUG
    /// Length of the buffer currently loaded for a line, so a test can tell which source it
    /// came from without needing to listen to it.
    func loadedVoiceFrameLengthForTesting(slug: String) -> AVAudioFrameCount? {
        voiceBuffers[slug]?.frameLength
    }
    #endif

    // MARK: - Transport

    /// Starts (or restarts) playback from `offset` seconds into the scene.
    func play(from offset: TimeInterval = 0) {
        guard let pack else { return }

        stopNodes()

        AudioSessionManager.shared.activate()

        do {
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
        } catch {
            print("❌ DubPlayer failed to start engine: \(error)")
            return
        }

        playbackStartOffset = max(0, offset)
        scheduleBacking(from: playbackStartOffset)
        scheduleVoices(from: playbackStartOffset)

        // Only the nodes that were actually connected may be started
        if backingBuffer != nil { backingNode.play() }
        voiceNodes.forEach { $0.play() }

        wallClockAnchor = Date()
        currentTime = playbackStartOffset
        isPlaying = true
        startProgressTimer()

        AnalyticsManager.shared.trackDubPlaybackStarted(mode: mode.rawValue)
    }

    func stop() {
        stopNodes()
        if engine.isRunning { engine.stop() }
        isPlaying = false
        currentTime = 0
        playbackStartOffset = 0
        wallClockAnchor = nil
        stopProgressTimer()
    }

    func togglePlayback() {
        if isPlaying {
            stop()
        } else {
            play(from: 0)
        }
    }

    private func stopNodes() {
        if backingBuffer != nil { backingNode.stop() }
        voiceNodes.forEach { $0.stop() }
        stopProgressTimer()
    }

    // MARK: - Scheduling

    private func scheduleBacking(from offset: TimeInterval) {
        guard let backingBuffer,
              let trimmed = DubAudioLoader.trimming(backingBuffer, fromOffset: offset) else { return }

        backingNode.scheduleBuffer(trimmed, at: nil, options: [])
    }

    /// Each lane's lines go onto that lane's node at their own start time. A node renders
    /// silence between the lines it holds, so timing can't drift within a lane, and lines in
    /// different lanes are summed rather than one of them being dropped.
    private func scheduleVoices(from offset: TimeInterval) {
        let sampleRate = DubAudioLoader.canonicalFormat.sampleRate

        for (laneIndex, lane) in voiceLanes.enumerated() {
            guard laneIndex < voiceNodes.count else { break }
            let node = voiceNodes[laneIndex]

            for line in lane {
                guard let buffer = voiceBuffers[line.slug] else { continue }

                let placedAt = placement(of: line)
                let placedEnd = placedAt + Double(buffer.frameLength) / sampleRate
                guard placedEnd > offset else { continue }

                let scheduledBuffer: AVAudioPCMBuffer
                let startSeconds: TimeInterval

                if placedAt >= offset {
                    scheduledBuffer = buffer
                    startSeconds = placedAt - offset
                } else {
                    // Playback begins mid-line — drop the part already gone by
                    guard let trimmed = DubAudioLoader.trimming(buffer, fromOffset: offset - placedAt) else { continue }
                    scheduledBuffer = trimmed
                    startSeconds = 0
                }

                let time = AVAudioTime(
                    sampleTime: AVAudioFramePosition(startSeconds * sampleRate),
                    atRate: sampleRate
                )

                node.scheduleBuffer(scheduledBuffer, at: time, options: [])
            }
        }
    }

    // MARK: - Progress

    private func startProgressTimer() {
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateProgress() }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard isPlaying else { return }

        currentTime = playbackStartOffset + elapsedSincePlaybackStart()

        if currentTime >= duration {
            stop()
        }
    }

    /// Prefers the audio render clock; falls back to wall time for a pack with no backing
    /// track, where the voice node is silent (and reports no time) between lines.
    private func elapsedSincePlaybackStart() -> TimeInterval {
        if backingBuffer != nil,
           let renderTime = backingNode.lastRenderTime,
           let playerTime = backingNode.playerTime(forNodeTime: renderTime),
           playerTime.sampleTime > 0 {
            return Double(playerTime.sampleTime) / playerTime.sampleRate
        }

        guard let wallClockAnchor else { return 0 }
        return Date().timeIntervalSince(wallClockAnchor)
    }

    // MARK: - Cleanup

    func cleanup() {
        stop()
        voiceBuffers.removeAll()
        backingBuffer = nil
        pack = nil
    }
}
