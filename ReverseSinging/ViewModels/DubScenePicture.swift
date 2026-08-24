//
//  DubScenePicture.swift
//  ReverseSinging
//
//  Drives the scene video for one line at a time
//

import AVFoundation
import Combine

/// Owns the `AVPlayer` for a pack's scene video and parks it on whichever line is being
/// worked on.
///
/// Always muted. In the record screen the mic is open and anything through the speaker lands
/// in the take; in the playback screen the audio comes from `DubPlayer`, which mixes the
/// backing track with the user's voices. The video is picture only in both cases.
@MainActor
final class DubScenePicture: ObservableObject {

    /// Nil when the pack ships no playable video — callers fall back to the per-line still.
    @Published private(set) var player: AVPlayer?

    private var endObserver: Any?
    private var stopAt: TimeInterval?
    /// Where to jump back to when the line ends, or nil to stop there instead.
    private var loopStart: TimeInterval?
    /// Whole-scene playback requested while AVPlayer is still opening the local file.
    private var pendingSceneAnchor: DubPlaybackAnchor?
    private var statusObservation: NSKeyValueObservation?
    /// A rewind is in flight. The time observer keeps firing during the seek, and without
    /// this every one of those ticks would queue another seek.
    private var isRewinding = false

    // MARK: - Setup

    func configure(with pack: DubPack) {
        guard player == nil, let url = pack.videoURL else { return }

        let player = AVPlayer(url: url)
        player.isMuted = true
        // This is a local file. Waiting to build a network-style playback buffer only makes
        // the picture miss the host-time start shared with the audio engine.
        player.automaticallyWaitsToMinimizeStalling = false
        // Without this the player stalls at the end of a segment instead of holding the frame.
        player.actionAtItemEnd = .pause
        self.player = player
        observeReadiness(of: player)
    }

    // MARK: - Positioning

    /// Parks on a line's first frame without playing, so the picture matches the line the
    /// user is about to perform.
    func show(_ line: DubLine) {
        clearEndObserver()
        guard let player else { return }
        player.pause()
        seek(player, to: line.startTime)
    }

    /// Plays a line's stretch of the scene.
    ///
    /// - Parameter loop: when true the line repeats instead of stopping at its end. Takes
    ///   routinely run longer than the line they are matching, and a picture frozen on the
    ///   last frame for the rest of the take reads as broken; looping keeps the performer
    ///   on the beat and makes it obvious the video is live.
    func play(_ line: DubLine, loop: Bool = false) {
        guard let player else { return }
        clearEndObserver()

        seek(player, to: line.startTime)
        stopAt = line.endTime
        loopStart = loop ? line.startTime : nil
        observeEnd(on: player)
        player.play()
    }

    func stop(returningTo line: DubLine?) {
        clearEndObserver()
        guard let player else { return }
        player.pause()
        if let line { seek(player, to: line.startTime) }
    }

    // MARK: - Whole Scene

    /// Plays the whole scene on the audio engine's exact host-time boundary.
    ///
    /// `setRate(_:time:atHostTime:)` establishes one timebase mapping in AVPlayer. Starting
    /// with `seek` followed by `play` used two asynchronous operations and made the video run
    /// before the audio node's scheduled lead-in had elapsed.
    func playScene(at anchor: DubPlaybackAnchor) {
        guard let player else { return }
        clearEndObserver()
        pendingSceneAnchor = anchor
        startPendingScene(on: player)
    }

    func pauseScene() {
        pendingSceneAnchor = nil
        player?.pause()
    }

    /// Nudges the picture back onto the audio clock. `DubPlayer` runs the mix on its own
    /// engine, so audio is the master and the video is corrected towards it — never the
    /// other way, which would stutter the mix.
    func resync(to time: TimeInterval, tolerance: TimeInterval = 0.25) {
        guard let player, player.status == .readyToPlay, player.rate != 0 else { return }
        let drift = abs(player.currentTime().seconds - time)
        guard drift > tolerance else { return }

        // A local file should not drift once both clocks share an anchor. This is only a
        // recovery path for a decode stall or interruption, so re-anchor in one operation
        // instead of issuing repeated zero-tolerance seeks every few timer ticks.
        player.setRate(
            1,
            time: CMTime(seconds: max(0, time), preferredTimescale: 600),
            atHostTime: CMClockGetTime(CMClockGetHostTimeClock())
        )
    }

    // MARK: - Testing

    #if DEBUG
    /// Points the picture at a video file directly, bypassing `DubPack` path resolution so a
    /// test can use a fixture outside the app's pack directory.
    func configureForTesting(videoURL: URL) {
        let player = AVPlayer(url: videoURL)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .pause
        self.player = player
        observeReadiness(of: player)
    }

    var rateForTesting: Float { player?.rate ?? 0 }
    var currentTimeForTesting: TimeInterval { player?.currentTime().seconds ?? 0 }
    var isReadyForTesting: Bool { player?.status == .readyToPlay }
    #endif

    // MARK: - Teardown

    func tearDown() {
        clearEndObserver()
        pendingSceneAnchor = nil
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
    }

    // MARK: - Helpers

    private func seek(_ player: AVPlayer, to time: TimeInterval) {
        player.seek(
            to: CMTime(seconds: max(0, time), preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    /// Synchronized playback raises an Objective-C exception unless AVPlayer is ready. Keep
    /// the request and apply it when the local asset has opened; if that happens after the
    /// audio deadline, advance the requested video time by exactly the missed host duration.
    private func observeReadiness(of player: AVPlayer) {
        statusObservation?.invalidate()
        statusObservation = player.observe(\.status, options: [.initial, .new]) { [weak self, weak player] _, _ in
            Task { @MainActor [weak self, weak player] in
                guard let self, let player else { return }
                self.startPendingScene(on: player)
            }
        }
    }

    private func startPendingScene(on player: AVPlayer) {
        guard player.status == .readyToPlay, let anchor = pendingSceneAnchor else { return }
        pendingSceneAnchor = nil

        let now = mach_absolute_time()
        var scheduledHostTime = anchor.hostTime
        var scheduledOffset = max(0, anchor.offset)

        if scheduledHostTime <= now {
            // Leave a tiny scheduling runway after readiness. The audio time at that future
            // instant is the original offset plus all host time elapsed since its deadline.
            let runway: TimeInterval = 0.01
            let elapsed = AVAudioTime.seconds(forHostTime: now - scheduledHostTime) + runway
            scheduledOffset += elapsed
            scheduledHostTime = now + AVAudioTime.hostTime(forSeconds: runway)
        }

        player.setRate(
            1,
            time: CMTime(seconds: scheduledOffset, preferredTimescale: 600),
            atHostTime: CMClockMakeHostTimeFromSystemUnits(scheduledHostTime)
        )
    }

    private func observeEnd(on player: AVPlayer) {
        endObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.03, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            // The observer is delivered on the main queue, but the closure isn't typed as
            // main-actor isolated, so state it explicitly rather than hopping through a Task
            // — a hop would let the video overrun the line before the pause landed.
            MainActor.assumeIsolated {
                guard let self, let stopAt = self.stopAt else { return }
                guard time.seconds >= stopAt else { return }

                guard let loopStart = self.loopStart else {
                    self.clearEndObserver()
                    player.pause()
                    return
                }

                guard !self.isRewinding else { return }
                self.isRewinding = true
                player.seek(
                    to: CMTime(seconds: max(0, loopStart), preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.isRewinding = false }
                }
            }
        }
    }

    private func clearEndObserver() {
        if let endObserver {
            player?.removeTimeObserver(endObserver)
        }
        endObserver = nil
        stopAt = nil
        loopStart = nil
        isRewinding = false
    }
}
