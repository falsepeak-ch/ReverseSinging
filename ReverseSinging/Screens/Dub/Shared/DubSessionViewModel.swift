//
//  DubSessionViewModel.swift
//  ReverseSinging
//
//  One pack's dub session: the line being worked on, its takes and scores, and the players
//  the pack, record and playback screens share
//

import SwiftUI
import Combine
import AVFoundation
import DubAudio
import DubScoring

/// What the screens of one pack's dub have in common.
///
/// `DubPackDetailViewModel` creates it and hands it to the record and playback screens, which
/// keep their own state in their own view models. Kept here is only what more than one of them
/// reads: which line is up, which lines have takes and footage, how they scored, the reference
/// preview, and the scene player. The scene player especially: it keeps the voices it has
/// loaded between plays, so a second visit to playback does not read every take again.
@MainActor
final class DubSessionViewModel: ObservableObject {

    // MARK: - Session

    let pack: DubPack

    @Published var currentLineIndex: Int = 0
    @Published private(set) var recordedSlugs: Set<String> = []

    // MARK: - Scoring

    /// How each recorded line scored against the original, keyed by slug. Read from disk on
    /// open and updated in place as takes land, so the list never has to be re-measured.
    @Published private(set) var lineScores: [String: DubLineScore] = [:]

    /// The line whose score was just measured, for the record screen to celebrate. Cleared
    /// when the user moves on, so it marks *this* take rather than the last one to finish.
    @Published var latestScore: DubLineScore?

    /// Whether takes are being marked at all. Off unless the user asked for it, see
    /// `DubScoringPreference`.
    var isScoringEnabled: Bool { DubScoringPreference.shared.isEnabled }

    // MARK: - Booth Cam

    /// Which lines have booth footage, so the list can mark them and the exporter can find
    /// them. Kept beside `recordedSlugs` rather than derived from it: a line can have a voice
    /// take and no footage, if it was recorded before the camera was switched on.
    @Published private(set) var boothSlugs: Set<String> = []

    var hasAnyBoothTake: Bool { !boothSlugs.isEmpty }

    /// The booth clip the monitor should be showing instead of the live camera, or nil when
    /// it should be showing what the camera sees now.
    ///
    /// Set while a take is being played back, so the monitor becomes a playback window on the
    /// take rather than a mirror: the point of filming was to watch it afterwards, and the
    /// only screen the footage was reachable from until now was the export.
    @Published private(set) var boothPlaybackURL: URL?

    func hasBoothTake(_ line: DubLine) -> Bool { boothSlugs.contains(line.slug) }

    // MARK: - Reference Preview

    @Published private(set) var isPreviewingReference = false
    /// 0...1 through whatever the preview player is playing, for the waveform playhead.
    @Published private(set) var previewProgress: Double = 0

    @Published var errorMessage: String?

    // MARK: - Services

    private let referencePlayer = AudioPlayer()
    let scenePlayer = DubPlayer()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(pack: DubPack) {
        self.pack = pack
        refreshRecordedSlugs()
        // Read whether or not scoring is on: turning it off hides the scores, it does not
        // throw them away, so turning it back on shows what was already measured.
        lineScores = DubScoreStore.shared.scores(forPackID: pack.id)
        setupBindings()
        lineDidChange()
    }

    private func setupBindings() {
        referencePlayer.$isPlaying
            .assign(to: &$isPreviewingReference)

        // The monitor goes back to the live camera whenever the take stops, however it
        // stopped: reaching the end, being stopped, or another line being selected.
        referencePlayer.$isPlaying
            .filter { !$0 }
            .sink { [weak self] _ in self?.boothPlaybackURL = nil }
            .store(in: &cancellables)

        referencePlayer.$currentTime
            .combineLatest(referencePlayer.$duration)
            .map { time, duration in duration > 0 ? min(1, time / duration) : 0 }
            .assign(to: &$previewProgress)
    }

    // MARK: - Lines

    var currentLine: DubLine? {
        guard pack.lines.indices.contains(currentLineIndex) else { return nil }
        return pack.lines[currentLineIndex]
    }

    var recordedCount: Int { recordedSlugs.count }

    var hasAnyTake: Bool { !recordedSlugs.isEmpty }

    func isRecorded(_ line: DubLine) -> Bool { recordedSlugs.contains(line.slug) }

    func select(_ line: DubLine) {
        guard let index = pack.lines.firstIndex(where: { $0.id == line.id }) else { return }
        stopPlayback()
        currentLineIndex = index
        lineDidChange()
    }

    func goToNextLine() {
        guard currentLineIndex < pack.lines.count - 1 else { return }
        stopPlayback()
        currentLineIndex += 1
        lineDidChange()
        SoundManager.shared.play(.mechanicalClick)
        HapticManager.shared.light()
    }

    func goToPreviousLine() {
        guard currentLineIndex > 0 else { return }
        stopPlayback()
        currentLineIndex -= 1
        lineDidChange()
        SoundManager.shared.play(.mechanicalClick)
        HapticManager.shared.light()
    }

    /// Jumps to the first line without a take, or stays put if the scene is fully dubbed.
    func jumpToFirstUnrecordedLine() {
        if let index = pack.lines.firstIndex(where: { !recordedSlugs.contains($0.slug) }) {
            currentLineIndex = index
            lineDidChange()
        }
    }

    /// The waveforms of the new line are the record screen's to load, see
    /// `DubRecordViewModel.lineDidChange()`.
    private func lineDidChange() {
        // The card belongs to the take that was just performed, not to the next line.
        latestScore = currentLine.flatMap { score(for: $0) }
    }

    private func refreshRecordedSlugs() {
        let directory = AudioFileManager.shared.dubTakesDirectory(packID: pack.id)
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        recordedSlugs = Set(
            contents
                .filter { $0.pathExtension.lowercased() == "caf" }
                .map { $0.deletingPathExtension().lastPathComponent }
        )

        refreshBoothSlugs()
    }

    private func refreshBoothSlugs() {
        let directory = AudioFileManager.shared.dubBoothDirectory(packID: pack.id)
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        boothSlugs = Set(
            contents
                .filter { $0.pathExtension.lowercased() == "mov" }
                .map { $0.deletingPathExtension().lastPathComponent }
        )
    }

    // MARK: - Takes

    /// Files a take the record screen has just saved.
    func markRecorded(_ line: DubLine) {
        recordedSlugs.insert(line.slug)
    }

    /// Notes whether a take left footage. A clip that never got a frame leaves no file, so
    /// the line simply has no footage rather than an empty one.
    func setBoothTake(_ hasFootage: Bool, for line: DubLine) {
        if hasFootage {
            boothSlugs.insert(line.slug)
        } else {
            boothSlugs.remove(line.slug)
        }
    }

    // MARK: - Reference Preview

    /// Plays the pack's own recording of the current line, so the user hears the delivery
    /// they're matching. `DubRecordViewModel` keeps it from starting while the mic is open.
    func toggleReferencePreview() {
        guard let line = currentLine else { return }

        if isPreviewingReference {
            referencePlayer.stop()
            return
        }

        // This is the film talking, not the user, so the monitor stays a mirror.
        boothPlaybackURL = nil

        do {
            try referencePlayer.loadAudio(from: pack.referenceAudioURL(for: line))
            referencePlayer.play()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Plays back the user's own take for this line, if there is one.
    func playCurrentTake() {
        guard let line = currentLine, isRecorded(line) else { return }

        if isPreviewingReference {
            referencePlayer.stop()
            return
        }

        do {
            try referencePlayer.loadAudio(from: pack.takeURL(for: line))
            // Set before play, so the monitor has already swapped when the first sample is
            // heard rather than a frame after it.
            boothPlaybackURL = hasBoothTake(line) ? pack.boothTakeURL(for: line) : nil
            referencePlayer.play()
        } catch {
            boothPlaybackURL = nil
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Scoring

    /// Every line the user has dubbed, rolled up.
    var sceneScore: DubSceneScore {
        DubSceneScore(
            lines: isScoringEnabled ? pack.lines.compactMap { lineScores[$0.slug] } : [],
            totalLines: pack.lines.count
        )
    }

    func score(for line: DubLine) -> DubLineScore? {
        guard isScoringEnabled else { return nil }
        return lineScores[line.slug]
    }

    /// Marks takes recorded while scoring was off.
    ///
    /// Turning scoring on part-way through a scene would otherwise show a panel with a
    /// handful of lines in it and the rest blank, which reads as broken rather than as
    /// "those ones weren't measured". Each take is scored from the file, so the results are
    /// the same ones recording them with scoring on would have produced.
    ///
    /// One line at a time, publishing as it goes: a long scene fills the panel in rather
    /// than sitting empty until the last take is done.
    func scoreTakesRecordedBeforeScoringWasOn() async {
        guard isScoringEnabled else { return }

        let missing = pack.lines.filter { recordedSlugs.contains($0.slug) && lineScores[$0.slug] == nil }
        guard !missing.isEmpty else { return }

        let packID = pack.id

        for line in missing {
            let takeURL = pack.takeURL(for: line)
            let referenceURL = pack.referenceAudioURL(for: line)

            let measured = await Task.detached(priority: .utility) {
                guard let score = DubScorer.score(takeURL: takeURL, referenceURL: referenceURL, line: line) else {
                    return DubLineScore?.none
                }
                DubScoreStore.shared.save(score, forPackID: packID)
                return score
            }.value

            guard let measured else { continue }
            lineScores[line.slug] = measured
        }
    }

    /// Measures a freshly-recorded take and files the result.
    ///
    /// Runs after the take has been normalised to the line's length, so what is scored is the
    /// same audio the mix will use. Off the main actor. It reads and analyses two whole clips
    ///. And silent on failure: a line that cannot be measured shows no score rather than a
    /// zero the performer did not earn.
    func scoreTake(for line: DubLine) async {
        guard isScoringEnabled else { return }

        let takeURL = pack.takeURL(for: line)
        let referenceURL = pack.referenceAudioURL(for: line)
        let packID = pack.id

        let measured = await Task.detached(priority: .userInitiated) {
            guard let score = DubScorer.score(takeURL: takeURL, referenceURL: referenceURL, line: line) else {
                return DubLineScore?.none
            }
            DubScoreStore.shared.save(score, forPackID: packID)
            return score
        }.value

        guard let measured else { return }

        lineScores[line.slug] = measured
        latestScore = measured

        AnalyticsManager.shared.trackDubLineScored(
            lineIndex: line.index,
            score: measured.overall,
            timing: measured.timing
        )
    }

    // MARK: - Scene Playback

    func playScene(mode: DubPlaybackMode, from offset: TimeInterval = 0) async {
        stopPlayback()
        await scenePlayer.prepare(pack: pack, mode: mode)
        scenePlayer.play(from: offset)
    }

    /// Silences the reference and the scene. The record screen closes its own microphone and
    /// headphone monitor first, see `DubRecordViewModel.stop()`.
    func stopPlayback() {
        referencePlayer.stop()
        scenePlayer.stop()
    }

    // MARK: - Cleanup

    func cleanup() {
        stopPlayback()
        referencePlayer.cleanup()
        scenePlayer.cleanup()
    }
}
