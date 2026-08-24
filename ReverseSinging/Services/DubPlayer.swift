//
//  DubPlayer.swift
//  ReverseSinging
//
//  Timeline playback of a dub pack: backing track plus one voice per line
//

import AVFoundation
import Combine

/// A point on the scene timeline tied to the device host clock.
///
/// AVAudioPlayerNode and AVPlayer both understand this clock, which makes it the reliable
/// boundary between the separately rendered voice mix and picture.
nonisolated struct DubPlaybackAnchor: Equatable, Sendable {
    let offset: TimeInterval
    let hostTime: UInt64
}

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

/// Plays a whole scene by scheduling every line where it belongs on the timeline.
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

    /// Each line's voice, trimmed and timed by `DubVoiceAlignment`, keyed by slug.
    ///
    /// Only ever valid for `loadedMode`: the two modes key on the same slugs but read from
    /// different files, so a cache shared between them hands Original's references back to My
    /// Dub and you listen to the film instead of your own take.
    private var placements: [String: DubVoiceAlignment.Placement] = [:]
    private var loadedMode: DubPlaybackMode?

    private var pack: DubPack?
    private var mode: DubPlaybackMode = .original
    private var playbackStartOffset: TimeInterval = 0

    /// The one start point shared by the audio engine and the scene picture.
    ///
    /// Audio and video used to be told to play in two separate callbacks. The audio nodes
    /// deliberately wait for `startLeadIn`, while AVPlayer began immediately and was then
    /// repeatedly exact-seeked back towards the audio clock. High-frame-rate scenes made
    /// those corrections especially visible. Publishing the audio engine's actual host-time
    /// deadline lets AVPlayer map the requested video frame onto that same instant instead.
    private(set) var playbackAnchor: DubPlaybackAnchor?

    /// Backing track sits under the voices rather than competing with them.
    private static let backingGain: Float = 0.75

    /// How far ahead of "now" playback is scheduled to begin.
    ///
    /// Every node is handed this one host time, so they start on the same sample instead of
    /// each starting whenever its own `play()` happened to be reached. Long enough for the
    /// render thread to pick all of them up before the deadline passes, short enough that the
    /// button still feels instant.
    private static let startLeadIn: TimeInterval = 0.12

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

    /// Reads the backing track and every voice the chosen mode needs, and works out where
    /// each one belongs on the timeline.
    ///
    /// All of it off the main actor: a scene is 60-odd wavs plus a five-minute backing track,
    /// and the alignment pass measures every take. Safe to call repeatedly — a mode that is
    /// already loaded is reused rather than re-read.
    func prepare(pack: DubPack, mode: DubPlaybackMode) async {
        isPreparing = true
        defer { isPreparing = false }

        self.pack = pack
        self.mode = mode
        duration = pack.duration

        let backingURL = pack.backingTrackURL
        let sources = voiceSources(for: pack, mode: mode)
        let alreadyLoaded = loadedMode == mode ? placements : [:]

        let loaded: (AVAudioPCMBuffer?, [String: DubVoiceAlignment.Placement]) =
            await Task.detached(priority: .userInitiated) {
                var backing: AVAudioPCMBuffer?
                if let backingURL {
                    backing = try? DubAudioLoader.loadBuffer(from: backingURL)
                }

                var placed: [String: DubVoiceAlignment.Placement] = [:]
                for source in sources {
                    if let cached = alreadyLoaded[source.line.slug] {
                        placed[source.line.slug] = cached
                        continue
                    }
                    guard let buffer = try? DubAudioLoader.loadVoiceBuffer(from: source.url) else { continue }

                    placed[source.line.slug] = source.isTake
                        ? DubVoiceAlignment.place(
                            take: buffer,
                            for: source.line,
                            referenceURL: source.referenceURL
                          )
                        : DubVoiceAlignment.placeReference(buffer, for: source.line)
                }

                return (backing, placed)
            }.value

        backingBuffer = loaded.0
        backingFormat = loaded.0?.format
        placements = loaded.1
        loadedMode = mode

        // Only lines that actually have audio take up a lane.
        let sampleRate = DubAudioLoader.canonicalFormat.sampleRate
        voiceLanes = DubVoiceLanes.assign(
            pack.lines.filter { placements[$0.slug] != nil },
            start: { self.placements[$0.slug]?.startTime ?? $0.startTime },
            end: { line in
                guard let placement = self.placements[line.slug] else { return line.endTime }
                return placement.endTime(sampleRate: sampleRate)
            }
        )

        connectNodes()
    }

    /// Where a line's voice comes from in this mode.
    private struct VoiceSource: Sendable {
        let line: DubLine
        let url: URL
        /// True for the user's own take, which is aligned onto the original's onset. A
        /// reference is left where it was cut from.
        let isTake: Bool
        /// Only opened for a take on a line with no measured speech window — see
        /// `DubVoiceAlignment.place(take:for:referenceURL:)`.
        let referenceURL: URL
    }

    /// In `.myDub`, a line the user hasn't recorded falls back to the reference so the scene
    /// still plays end to end.
    private func voiceSources(for pack: DubPack, mode: DubPlaybackMode) -> [VoiceSource] {
        pack.lines.map { line in
            let reference = pack.referenceAudioURL(for: line)

            guard mode == .myDub else {
                return VoiceSource(line: line, url: reference, isTake: false, referenceURL: reference)
            }

            let take = pack.takeURL(for: line)
            guard FileManager.default.fileExists(atPath: take.path) else {
                return VoiceSource(line: line, url: reference, isTake: false, referenceURL: reference)
            }

            return VoiceSource(line: line, url: take, isTake: true, referenceURL: reference)
        }
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
        placements[line.slug] = nil
    }

    #if DEBUG
    /// Length of the buffer currently loaded for a line, so a test can tell which source it
    /// came from without needing to listen to it.
    func loadedVoiceFrameLengthForTesting(slug: String) -> AVAudioFrameCount? {
        placements[slug]?.buffer.frameLength
    }

    /// Where a line's voice was placed on the timeline.
    func placementStartForTesting(slug: String) -> TimeInterval? {
        placements[slug]?.startTime
    }
    #endif

    // MARK: - Transport

    /// Starts (or restarts) playback from `offset` seconds into the scene.
    func play(from offset: TimeInterval = 0) {
        guard pack != nil else { return }

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

        // Every node gets the same deadline, so the backing track and the voices begin on the
        // same sample. Starting them one `play()` at a time leaves each to begin on whichever
        // render cycle its own call happened to land in, and the lanes drift apart by a
        // quantum or more — the one thing a dub cannot survive.
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: Self.startLeadIn)
        let startTime = AVAudioTime(hostTime: hostTime)

        // Only the nodes that were actually connected may be started
        if backingBuffer != nil { backingNode.play(at: startTime) }
        voiceNodes.forEach { $0.play(at: startTime) }

        playbackAnchor = DubPlaybackAnchor(offset: playbackStartOffset, hostTime: hostTime)
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
        playbackAnchor = nil
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

    /// Each lane's voices go onto that lane's node at their own start time. A node renders
    /// silence between the buffers it holds, so timing can't drift within a lane, and voices
    /// in different lanes are summed rather than one of them being dropped.
    private func scheduleVoices(from offset: TimeInterval) {
        let sampleRate = DubAudioLoader.canonicalFormat.sampleRate

        for (laneIndex, lane) in voiceLanes.enumerated() {
            guard laneIndex < voiceNodes.count else { break }
            let node = voiceNodes[laneIndex]

            for line in lane {
                guard let placement = placements[line.slug] else { continue }
                guard placement.endTime(sampleRate: sampleRate) > offset else { continue }

                let scheduledBuffer: AVAudioPCMBuffer
                let startSeconds: TimeInterval

                if placement.startTime >= offset {
                    scheduledBuffer = placement.buffer
                    startSeconds = placement.startTime - offset
                } else {
                    // Playback begins mid-line — drop the part already gone by
                    guard let trimmed = DubAudioLoader.trimming(
                        placement.buffer,
                        fromOffset: offset - placement.startTime
                    ) else { continue }
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
            Task { @MainActor [weak self] in self?.updateProgress() }
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

    /// Seconds since the deadline every node was started on.
    ///
    /// Measured against that exact host time rather than against a player node's own clock: a voice
    /// node reports nothing during the silence between its lines, and a pack may have no
    /// backing track at all, so neither is a clock the whole scene can be read from. The host
    /// clock is the one the nodes were scheduled against, and it runs whether or not anything
    /// is sounding. Negative until the lead-in elapses, which is why it is floored at zero.
    private func elapsedSincePlaybackStart() -> TimeInterval {
        guard let anchor = playbackAnchor else { return 0 }
        let now = mach_absolute_time()
        guard now > anchor.hostTime else { return 0 }
        return AVAudioTime.seconds(forHostTime: now - anchor.hostTime)
    }

    // MARK: - Cleanup

    func cleanup() {
        stop()
        placements.removeAll()
        loadedMode = nil
        backingBuffer = nil
        pack = nil
    }
}
