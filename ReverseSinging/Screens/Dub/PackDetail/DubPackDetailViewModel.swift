//
//  DubPackDetailViewModel.swift
//  ReverseSinging
//
//  One pack's screen: the way into the recorder and playback, the export flow, and the render
//

import SwiftUI
import Combine
import DubScoring
import DubCompositing

/// Drives the pack screen, and owns the pack's dub session.
///
/// The session is created here, once per visit to the pack, and handed to the record and
/// playback screens. Its changes are passed on as this model's own, because nearly everything
/// the pack screen shows, the takes, the scores, the footage count, lives in it.
@MainActor
final class DubPackDetailViewModel: ObservableObject {

    let pack: DubPack
    let session: DubSessionViewModel
    private let library: DubPackLibrary

    // MARK: - Presentation

    @Published var showRecorder = false
    @Published var playbackMode: DubPlaybackMode?

    // MARK: - Export Flow

    @Published var showExportOptions = false
    @Published var showShareNotice = false
    /// Nil for a whole-scene export, the line for one line's own.
    @Published private(set) var exportOptionsLine: DubLine?
    /// The export the user has configured but not yet agreed to send. Held between the
    /// options sheet and the attribution notice, which still has the last word.
    private var pendingExport: (cut: DubCut, frame: DubBoothFrame, includesBooth: Bool)?

    // MARK: - Damaged Video

    /// True for a pack whose video was converted by a build that dropped duplicate frames.
    ///
    /// Reads the file, so it is settled once when the screen appears rather than on every
    /// evaluation of the body.
    @Published private(set) var videoNeedsReimport = false

    // MARK: - Export

    @Published private(set) var isExporting = false
    @Published private(set) var exportStage: DubExportStage = .mixingAudio
    @Published private(set) var exportProgress: Double = 0
    @Published var exportedURL: URL?

    private var cancellables = Set<AnyCancellable>()

    init(pack: DubPack, library: DubPackLibrary) {
        self.pack = pack
        self.library = library
        session = DubSessionViewModel(pack: pack)

        session.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "DubPackDetail")
        // Takes that were here before the tips existed count too.
        if session.hasAnyTake { DubTips.hasRecordedATake = true }
        // The recorder cannot be up when this screen appears. Cleared here so an app
        // killed mid-take does not leave the flag set, and the tip held, for good.
        DubTips.isRecorderOpen = false
        #if DEBUG
        applyScreenshotPose()
        #endif
    }

    func onDisappear() {
        session.stopPlayback()
        library.reload()
    }

    func checkVideo() async {
        videoNeedsReimport = await DubPackLibrary.sceneVideoIsTruncated(pack)
    }

    /// Switching scoring on from the library and coming straight back marks what is already
    /// here rather than showing a half-empty panel.
    func scoringDidChange() async {
        guard session.isScoringEnabled else { return }
        await session.scoreTakesRecordedBeforeScoringWasOn()
        AnalyticsManager.shared.trackDubSceneScored(
            score: session.sceneScore.overall,
            recordedLines: session.sceneScore.recordedLines,
            totalLines: pack.lines.count
        )
    }

    // MARK: - Recorder

    func openRecorder() {
        session.jumpToFirstUnrecordedLine()
        showRecorder = true
    }

    func openRecorder(at line: DubLine) {
        session.select(line)
        showRecorder = true
    }

    /// Hooked to the recorder itself rather than to the ways into it, so a new way in cannot
    /// quietly stop being counted.
    func recorderDidAppear() {
        DubTips.isRecorderOpen = true
        AnalyticsManager.shared.trackDubPackOpened(
            title: pack.title,
            lineCount: pack.lines.count,
            recordedCount: library.recordedCount(for: pack),
            source: pack.source
        )
        CrashReporter.shared.set(.screen, "DubRecordView")
        CrashReporter.shared.set(.packLineCount, pack.lines.count)
        CrashReporter.shared.set(.packHasVideo, pack.videoFile != nil)
    }

    /// Fires once the cover has actually gone, which is when a tip on this screen can be
    /// presented. See `DubTips.isRecorderOpen`.
    func recorderDidDismiss() {
        DubTips.isRecorderOpen = false
    }

    // MARK: - Playback

    func playOriginal() {
        playbackMode = .original
    }

    func playMyDub() {
        playbackMode = .myDub
    }

    // MARK: - Export Flow

    /// Options first, then the notice. The notice is about provenance and is the last word
    /// before anything renders; what shape the file takes is a separate question and asking
    /// both in one panel made neither of them land.
    func beginExport(line: DubLine?) {
        exportOptionsLine = line
        showExportOptions = true
    }

    func cancelExportOptions() {
        showExportOptions = false
    }

    func configureExport(cut: DubCut, frame: DubBoothFrame, includesBooth: Bool) {
        showExportOptions = false
        pendingExport = (cut, frame, includesBooth)
        showShareNotice = true
    }

    func confirmExport() {
        guard let pending = pendingExport else { return }
        pendingExport = nil
        Task {
            await export(
                cut: pending.cut,
                frame: pending.frame,
                includesBooth: pending.includesBooth
            )
        }
    }

    // MARK: - Export

    /// How long an export of this cut will run, for the sheet's slate.
    func runtime(of cut: DubCut) -> TimeInterval {
        DubCutPlanner.segments(for: cut, pack: pack, recordedSlugs: session.recordedSlugs)
            .reduce(0) { $0 + $1.duration }
    }

    func export(
        cut: DubCut = .fullScene,
        frame: DubBoothFrame = .off,
        includesBooth: Bool = true
    ) async {
        guard session.hasAnyTake else {
            session.errorMessage = Strings.Dub.Error.nothingRecorded
            return
        }

        session.stopPlayback()
        isExporting = true
        exportProgress = 0
        SoundManager.shared.play(.reelSpinUp)
        defer { isExporting = false }

        do {
            let url = try await DubMixer.shared.export(
                pack: pack,
                cut: cut,
                frame: frame,
                includesBooth: includesBooth
            ) { [weak self] stage, value in
                Task { @MainActor [weak self] in
                    self?.exportStage = stage
                    self?.exportProgress = Self.overallProgress(stage: stage, value: value)
                }
            }

            exportedURL = url
            SoundManager.shared.play(.projectorChime)
            HapticManager.shared.success()
        } catch {
            session.errorMessage = error.localizedDescription
            SoundManager.shared.play(.errorThunk)
            HapticManager.shared.error()

            // The last step of the whole mode, after the user has recorded every line.
            // Failing here throws away the most work of any error in the app.
            CrashReporter.shared.record(error, context: "dub.export", keys: [
                "line_count": pack.lines.count,
                // The case name, not `.message`, which is localised and would split one
                // issue across seven languages.
                "stage": String(describing: exportStage)
            ])
        }
    }

    /// Weighted by what the stages actually cost, measured rather than guessed.
    ///
    /// The mix and the picture are a fraction of a second between them; the render at the end
    /// is nine tenths of the wait. The old weighting had it the other way round, so the bar
    /// raced to ninety per cent and then sat there for the whole of the actual work, which is
    /// the single most reliable way to make something feel slower than it is.
    private static func overallProgress(stage: DubExportStage, value: Double) -> Double {
        switch stage {
        case .mixingAudio: return value * 0.04
        case .renderingVideo: return 0.04 + value * 0.06
        case .finishing: return 0.10 + value * 0.90
        }
    }

    // MARK: - Screenshots

    #if DEBUG
    /// Freezes the export overlay mid-render for a screenshot. The real render is driven
    /// by the mixer, so there is no other way to hold this state still long enough to
    /// photograph it.
    private func poseExportForScreenshot(progress: Double) {
        exportStage = .renderingVideo
        exportProgress = progress
        isExporting = true
    }

    /// The same overlay, run through its stages for the app preview recording.
    ///
    /// A real export of this scene finishes in a couple of seconds and produces a share
    /// sheet, which is a system surface Apple does not allow in an app preview. This walks
    /// the bar instead, at the pace a longer scene actually renders at.
    private func runExportRampForScreenshot(over duration: TimeInterval) async {
        let steps = 60
        exportProgress = 0
        exportStage = .mixingAudio
        isExporting = true

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            exportProgress = progress
            // The same weighting the real export reports: the mix and the picture are over
            // almost at once, and the render at the end is nearly all of the wait.
            exportStage = progress < 0.04 ? .mixingAudio : (progress < 0.10 ? .renderingVideo : .finishing)
            try? await Task.sleep(for: .seconds(duration / Double(steps)))
            if Task.isCancelled { break }
        }

        isExporting = false
        exportProgress = 0
    }

    /// Keeps the reference playing under the record screen, so the still lands on a
    /// moving picture.
    ///
    /// The scenes ship with video, and the bay only rolls it while the line is being heard
    /// or performed. Sitting idle it shows the line's still, and a screenshot of that is a
    /// screenshot of a photograph in a dark frame; a screenshot mid-playback is the app
    /// doing the thing it is for. The line is barely two seconds long, so this restarts it
    /// rather than firing once and hoping the shutter agrees.
    private func keepScenePictureRolling() {
        Task {
            for _ in 0..<160 {
                if !session.isPreviewingReference {
                    session.toggleReferencePreview()
                }
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
        }
    }

    /// The App Store app preview, played by the app itself.
    ///
    /// Recorded with `simctl io recordVideo` while this runs, once per locale. Driving it
    /// from inside means the same 30 seconds come out of every locale, which tapping a
    /// simulator by hand could never promise. And the whole thing is real app in real
    /// use, which is what Apple requires of a preview.
    func runScreenshotTour() async {
        guard ScreenshotMode.isActive, ScreenshotMode.destination?.isTour == true else { return }

        let tour = ScreenshotMode.Tour.self

        func hold(_ seconds: TimeInterval) async {
            try? await Task.sleep(for: .seconds(seconds))
        }

        // 1. The pack: what a scene is, who is in it, how far in you are.
        await hold(tour.detailHold)

        // 2. The bay, on a line already dubbed, so the take is drawn over the reference.
        showRecorder = true
        await hold(tour.recorderOpen)

        // 3. Hear the original, then hear yourself against it.
        session.toggleReferencePreview()
        await hold(tour.listen)
        session.playCurrentTake()
        await hold(tour.playTake)

        // 4. The line-by-line loop, which is the actual shape of the game.
        session.goToNextLine()
        await hold(tour.lineStep)
        session.goToNextLine()
        await hold(tour.lineStep)

        // 5. Back out and watch the scene with your own voice in it.
        session.stopPlayback()
        showRecorder = false
        await hold(tour.backToDetail)
        playbackMode = .myDub
        await hold(tour.playback)
        playbackMode = nil
        await hold(tour.beforeExport)

        // 6. The render, which is what you came for.
        await runExportRampForScreenshot(over: tour.exportRamp)
        await hold(tour.tail)
    }

    /// Puts the session partway in, a line selected, takes behind it, and opens
    /// whichever full-screen surface the capture script asked for.
    private func applyScreenshotPose() {
        guard ScreenshotMode.isActive, let destination = ScreenshotMode.destination else { return }

        if pack.lines.indices.contains(ScreenshotMode.posedLineIndex) {
            session.select(pack.lines[ScreenshotMode.posedLineIndex])
        }

        if destination.opensRecorder {
            showRecorder = true
            keepScenePictureRolling()
        } else if destination.posesExport {
            poseExportForScreenshot(progress: ScreenshotMode.posedExportProgress)
        }
    }
    #endif
}
