//
//  DubPlaybackViewModel.swift
//  ReverseSinging
//
//  Program monitor: the scene and the booth footage kept on the mix's clock, and the scrubber
//

import Foundation
import Combine
import DubAudio

/// Plays a scene back, original or dubbed, with the picture and the booth footage following
/// the mix.
///
/// `DubPlayer` is the clock and belongs to the session, which keeps the voices it has loaded
/// for the next visit. The picture and the booth reel belong to this screen, and their changes
/// are passed on as this model's own, so the screen redraws when a video opens or a clip comes
/// up.
@MainActor
final class DubPlaybackViewModel: ObservableObject {

    let mode: DubPlaybackMode
    let pack: DubPack
    /// The session's scene player. Observed by the screen directly, for the clock.
    let player: DubPlayer

    let scenePicture = DubScenePictureViewModel()
    /// The performer's own footage, running alongside. Left empty in `.original`: that mode
    /// is the film, and the film has nobody filming themselves in the corner.
    let boothReel = DubBoothReelViewModel()

    @Published private(set) var sceneSamples: [Float] = []

    private let session: DubSessionViewModel

    /// True from the first touch on the timeline to the lift. The scene is held while the
    /// finger is down and picked up again after, if it was running before.
    private var isScrubbing = false
    private var wasPlayingBeforeScrub = false

    private var cancellables = Set<AnyCancellable>()

    init(session: DubSessionViewModel, mode: DubPlaybackMode) {
        self.session = session
        self.mode = mode
        pack = session.pack
        player = session.scenePlayer

        scenePicture.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        boothReel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Lines

    /// The line whose picture is on screen right now. The same lookup the exporter uses to
    /// pick slideshow frames, so what plays here is what gets rendered.
    var pictureLine: DubLine? {
        pack.line(at: player.currentTime)
    }

    /// The caption to burn in right now, or nil in a gap.
    ///
    /// Not the same question as `pictureLine`: a still has to show *something* for every
    /// frame of the scene, but a subtitle that stays up through the silence between two lines
    ///, having gone up a beat or two before the character opened their mouth, reads as
    /// broken. See `DubPack.captionLine(at:)`.
    var captionLine: DubLine? {
        pack.captionLine(at: player.currentTime)
    }

    var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(1, player.currentTime / player.duration)
    }

    // MARK: - Screen

    func start() async {
        scenePicture.configure(with: pack)
        if mode == .myDub {
            boothReel.configure(with: pack, slugs: session.boothSlugs)
        }
        await session.playScene(mode: mode)
    }

    func loadSceneWaveform() async {
        guard let url = pack.backingTrackURL else { return }
        sceneSamples = await WaveformSampler.shared.samples(from: url, buckets: 160)
    }

    func onDisappear() {
        scenePicture.tearDown()
        boothReel.tearDown()
        player.stop()
    }

    func close() {
        player.stop()
    }

    // MARK: - Sync

    /// The anchor rather than `isPlaying`: a seek mid-play restarts the engine on a new
    /// deadline without ever passing through "not playing", and the pictures have to move
    /// to the new deadline with it.
    func playbackAnchorDidChange(_ anchor: DubPlaybackAnchor?) {
        if let anchor {
            scenePicture.playScene(at: anchor)
        } else {
            scenePicture.pauseScene()
        }
        boothReel.follow(time: player.currentTime, anchor: anchor)
    }

    /// The mix is the master clock; the pictures are corrected towards it. Held, the head
    /// can still be moved, and the frame under it has to follow.
    func currentTimeDidChange(_ time: TimeInterval) {
        if player.isPlaying {
            scenePicture.resync(to: time)
        } else {
            scenePicture.showFrame(at: time)
        }
        boothReel.follow(time: time, anchor: player.playbackAnchor)
    }

    // MARK: - Transport

    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
        } else {
            player.resume()
        }
    }

    func seek(by step: TimeInterval) {
        player.seek(to: player.currentTime + step)
    }

    /// Moves the head to a point on the timeline, holding the scene for as long as the finger
    /// is down so dragging through it is silent rather than a stutter of restarts.
    func scrub(to fraction: Double) {
        guard player.duration > 0 else { return }

        if !isScrubbing {
            isScrubbing = true
            wasPlayingBeforeScrub = player.isPlaying
            player.pause()
        }

        player.seek(to: fraction * player.duration)
    }

    /// Picks the scene up again from the new place, if it was running before.
    func endScrub() {
        guard isScrubbing else { return }
        isScrubbing = false
        if wasPlayingBeforeScrub { player.resume() }
        HapticManager.shared.light()
    }
}
