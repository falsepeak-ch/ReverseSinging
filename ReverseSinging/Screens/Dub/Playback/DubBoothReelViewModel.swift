//
//  DubBoothReelViewModel.swift
//  ReverseSinging
//
//  The performer's own footage, played back in step with the scene
//

import AVFoundation
import Combine

/// Plays the booth clips over a scene as it runs, one line at a time.
///
/// A booth clip is one line long and starts at that line's zero, because `BoothRecorder`
/// writes it from the microphone's own anchor. So the scene timeline decides which clip is up
/// and where in it we are, and nothing here has to be told when a line begins. `DubPlayer` is
/// the clock: this is corrected towards it the way `DubScenePictureViewModel` is, never the other way,
/// which would stutter the mix.
///
/// Its own `AVPlayer`, not the scene's. Two pieces of footage are running at once.
@MainActor
final class DubBoothReelViewModel: ObservableObject {

    /// Where one line's footage lives, and when on the scene timeline it is up.
    nonisolated struct Clip: Equatable, Sendable {
        let slug: String
        let url: URL
        let start: TimeInterval
        let end: TimeInterval

        func contains(_ time: TimeInterval) -> Bool { time >= start && time < end }
    }

    /// The line whose footage is on screen, or nil between clips.
    @Published private(set) var currentSlug: String?

    let player = AVPlayer()

    private var clips: [Clip] = []
    private var currentClip: Clip?
    private var itemStatusObservation: NSKeyValueObservation?
    /// A start requested while the clip's file was still opening.
    private var pendingAnchor: DubPlaybackAnchor?
    /// The next clip's file, opened ahead of its line.
    ///
    /// Opening a file when its line begins costs a few frames of black in the monitor at
    /// exactly the moment the performer's face should appear. The lines are known in advance,
    /// so the next one is opened while the current one plays, or while the gap before it runs.
    private var upcoming: (slug: String, item: AVPlayerItem)?

    /// How far the clip may be from the scene before it is pulled back. The same figure the
    /// scene picture uses, for the same reason: comfortably under what a viewer notices.
    private static let tolerance: TimeInterval = 0.08

    init() {
        player.isMuted = true
        // Local files. Waiting to build a network-style buffer only makes the clip miss the
        // host-time start it is being mapped onto.
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .pause
    }

    // MARK: - Setup

    /// - Parameter slugs: the lines that have footage. The view model's answer rather than a
    ///   scan of the disk, so what plays here is what the line list says is there.
    func configure(with pack: DubPack, slugs: Set<String>) {
        clips = Self.clips(for: pack, slugs: slugs)
    }

    /// The lines that go on the reel, in scene order.
    nonisolated static func clips(for pack: DubPack, slugs: Set<String>) -> [Clip] {
        pack.lines
            .filter { slugs.contains($0.slug) && $0.duration > 0 }
            .map {
                Clip(slug: $0.slug, url: pack.boothTakeURL(for: $0), start: $0.startTime, end: $0.endTime)
            }
    }

    /// Which clip is up at `time`. Lines can overlap, and the monitor shows one thing, so
    /// the earlier line keeps it until it ends.
    nonisolated static func clip(at time: TimeInterval, in clips: [Clip]) -> Clip? {
        clips.first { $0.contains(time) }
    }

    // MARK: - Following the Scene

    /// Called on every tick of the scene clock, and whenever the scene starts or is held.
    ///
    /// - Parameters:
    ///   - time: where the scene is.
    ///   - anchor: the scene's host-time anchor while it is running, nil while it is held.
    func follow(time: TimeInterval, anchor: DubPlaybackAnchor?) {
        let clip = Self.clip(at: time, in: clips)

        if clip != currentClip {
            currentClip = clip
            currentSlug = clip?.slug
            load(clip)
        }

        prepareClip(after: time)

        guard let clip else { return }

        if let anchor {
            run(clip, anchor: anchor, sceneTime: time)
        } else {
            hold(clip, at: time)
        }
    }

    /// Stops following. The next `follow` starts a clip afresh.
    func tearDown() {
        pendingAnchor = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentClip = nil
        currentSlug = nil
        upcoming = nil
    }

    // MARK: - Helpers

    private func load(_ clip: Clip?) {
        pendingAnchor = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        player.pause()

        guard let clip else {
            player.replaceCurrentItem(with: nil)
            return
        }

        let item: AVPlayerItem
        if let upcoming, upcoming.slug == clip.slug {
            item = upcoming.item
            self.upcoming = nil
        } else {
            item = AVPlayerItem(url: clip.url)
        }
        player.replaceCurrentItem(with: item)

        // Synchronised playback raises unless the item is ready. Keep the request and apply
        // it when the file has opened, the way the scene picture does.
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.startPending() }
        }
    }

    /// Opens the file for whichever clip comes next after `time`, if it is not open already.
    ///
    /// `AVPlayerItem` starts reading its asset as soon as it exists, so by the time the line
    /// arrives the item is ready to be handed to the player rather than to the disk.
    private func prepareClip(after time: TimeInterval) {
        guard let next = clips.first(where: { $0.start > time }) else { return }
        guard upcoming?.slug != next.slug else { return }
        upcoming = (next.slug, AVPlayerItem(url: next.url))
    }

    /// Runs the clip on the scene's clock, re-anchoring only when it has actually strayed.
    private func run(_ clip: Clip, anchor: DubPlaybackAnchor, sceneTime: TimeInterval) {
        if player.rate != 0, player.currentItem?.status == .readyToPlay {
            let drift = abs(player.currentTime().seconds - (sceneTime - clip.start))
            guard drift > Self.tolerance else { return }
        }

        pendingAnchor = anchor
        startPending()
    }

    /// Parks the clip on the frame under a held head.
    private func hold(_ clip: Clip, at sceneTime: TimeInterval) {
        pendingAnchor = nil
        player.pause()
        player.seek(
            to: CMTime(seconds: max(0, sceneTime - clip.start), preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    /// Maps a clip time onto the scene's host-time anchor in one operation.
    ///
    /// The anchor says which host instant scene time `offset` falls on, and the host clock
    /// runs at one second per second from there, so any future instant can be turned into a
    /// scene time and from that into a clip time. A little runway after "now", so the
    /// instant has not already passed by the time AVPlayer acts on it.
    private func startPending() {
        guard let anchor = pendingAnchor, let clip = currentClip,
              let item = player.currentItem, item.status == .readyToPlay else { return }
        pendingAnchor = nil

        let now = mach_absolute_time()
        let runway: TimeInterval = 0.01
        let hostTime = max(anchor.hostTime, now + AVAudioTime.hostTime(forSeconds: runway))
        let sceneTime = anchor.offset + AVAudioTime.seconds(forHostTime: hostTime - anchor.hostTime)
        let clipTime = max(0, sceneTime - clip.start)

        player.setRate(
            1,
            time: CMTime(seconds: clipTime, preferredTimescale: 600),
            atHostTime: CMClockMakeHostTimeFromSystemUnits(hostTime)
        )
    }
}
