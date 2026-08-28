//
//  DubViewModel.swift
//  ReverseSinging
//
//  Drives one dub session: line-by-line recording, scene playback, export
//

import SwiftUI
import Combine
import QuartzCore
import AVFoundation

@MainActor
final class DubViewModel: ObservableObject {

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

    // MARK: - Recording

    @Published private(set) var isRecording = false
    /// Beats left in the slate, 3...1, or nil when no countdown is running.
    @Published private(set) var countdown: Int?
    @Published private(set) var recordingLevel: Float = 0
    @Published private(set) var recordingDuration: TimeInterval = 0
    /// The deadline at which both microphone sample zero and the line's first video frame
    /// begin. Published so `DubRecordView` can schedule its AVPlayer before the deadline.
    @Published private(set) var recordingAnchor: DubPlaybackAnchor?
    @Published var hasRecordingPermission = false
    @Published var showPermissionAlert = false

    // MARK: - Reference Preview

    @Published private(set) var isPreviewingReference = false
    /// 0...1 through whatever the preview player is playing, for the waveform playhead.
    @Published private(set) var previewProgress: Double = 0

    // MARK: - Waveforms

    /// How many bars one reference line is drawn with. Every other waveform on the screen
    /// is scaled against this, so they share a seconds-per-bar.
    static let referenceBuckets = 96

    /// The current line's reference audio, the bed the user's take is compared against.
    @Published private(set) var referenceSamples: [Float] = []
    /// The current line's finished take, drawn over the reference. Empty until one exists.
    @Published private(set) var takeSamples: [Float] = []
    /// The take as it is being performed, already on the reference's time axis: one entry per
    /// bar, written once and never rewritten. See `appendToLiveTrace(_:)`.
    @Published private(set) var liveTrace: [Float] = []

    /// Built on the reference's time axis and rebuilt for each take. See `LiveTrace`.
    /// Replaced with the current line's axis every time the mic opens; this is only a
    /// placeholder for the window before the first take.
    private var trace = LiveTrace(
        barDuration: DubViewModel.fallbackTraceBarDuration,
        maximumBars: DubViewModel.referenceBuckets * WaveformScaling.maxOverrun
    )
    /// When the mic actually opened, on the media clock, so a bar index comes from the moment
    /// a level was sampled rather than from how many levels have arrived.
    private var traceStartedAt: CFTimeInterval = 0

    // MARK: - Export

    @Published private(set) var isExporting = false
    @Published private(set) var exportStage: DubExportStage = .mixingAudio
    @Published private(set) var exportProgress: Double = 0
    @Published var exportedURL: URL?

    @Published var errorMessage: String?

    #if DEBUG
    /// Freezes the export overlay mid-render for a screenshot. The real render is driven
    /// by the mixer, so there is no other way to hold this state still long enough to
    /// photograph it.
    func poseExportForScreenshot(progress: Double) {
        exportStage = .renderingVideo
        exportProgress = progress
        isExporting = true
    }

    /// The same overlay, run through its stages for the app preview recording.
    ///
    /// A real export of this scene finishes in a couple of seconds and produces a share
    /// sheet, which is a system surface Apple does not allow in an app preview. This walks
    /// the bar instead, at the pace a longer scene actually renders at.
    func runExportRampForScreenshot(over duration: TimeInterval) async {
        let steps = 60
        exportProgress = 0
        exportStage = .mixingAudio
        isExporting = true

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            exportProgress = progress
            // The same weighting the real export reports: the mix is quick, the render
            // is most of the wait, and finishing is the tail.
            exportStage = progress < 0.25 ? .mixingAudio : (progress < 0.9 ? .renderingVideo : .finishing)
            try? await Task.sleep(for: .seconds(duration / Double(steps)))
            if Task.isCancelled { break }
        }

        isExporting = false
        exportProgress = 0
    }
    #endif

    // MARK: - Services

    private let recorder = AudioRecorder()
    private let referencePlayer = AudioPlayer()
    /// Feeds the reference to the performer's headphones during a take. Deliberately not
    /// `referencePlayer`: that one drives `isPreviewingReference`, which the record screen
    /// reads to decide whether the user is listening or performing, and the two must not be
    /// confused for one another.
    private let monitorPlayer = AudioPlayer()
    let scenePlayer = DubPlayer()

    private let slate = RecordSlate()
    private var autoStopTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Scheduling runway shared by AVAudioRecorder and AVPlayer. Starting either immediately
    /// makes the second API call late by construction; a short future deadline lets both
    /// subsystems commit before sample/frame zero.
    private static let recordingStartLeadIn: TimeInterval = 0.15

    // MARK: - Init

    init(pack: DubPack) {
        self.pack = pack
        refreshRecordedSlugs()
        // Read whether or not scoring is on: turning it off hides the scores, it does not
        // throw them away, so turning it back on shows what was already measured.
        lineScores = DubScoreStore.shared.scores(forPackID: pack.id)
        hasRecordingPermission = AudioSessionManager.shared.hasRecordPermission
        setupBindings()
        reloadWaveformsForCurrentLine()
    }

    private func setupBindings() {
        recorder.$recordingLevel
            .assign(to: &$recordingLevel)

        recorder.$recordingDuration
            .assign(to: &$recordingDuration)

        recorder.$isRecording
            .assign(to: &$isRecording)

        referencePlayer.$isPlaying
            .assign(to: &$isPreviewingReference)

        referencePlayer.$currentTime
            .combineLatest(referencePlayer.$duration)
            .map { time, duration in duration > 0 ? min(1, time / duration) : 0 }
            .assign(to: &$previewProgress)

        // Fed from the peak, not the meter level. The meter is average power on a dB curve,
        // right for the pulsing record button, wrong for a waveform, because it lifts every
        // quiet syllable to two thirds height and the trace comes out a flat block. The take
        // read back off disk is linear peaks, so drawing the live trace from anything else
        // made the shape visibly change the instant the recording stopped.
        recorder.$recordingPeak
            .sink { [weak self] peak in
                self?.appendToLiveTrace(peak)
            }
            .store(in: &cancellables)
    }

    // MARK: - Waveforms

    /// Reads the shapes for a line: its reference audio always, its take when one exists.
    func loadWaveforms(for line: DubLine?) async {
        guard let line else {
            referenceSamples = []
            takeSamples = []
            return
        }

        let buckets = Self.referenceBuckets
        referenceSamples = await WaveformSampler.shared.samples(
            from: pack.referenceAudioURL(for: line),
            buckets: buckets
        )

        await loadTakeWaveform(for: line)
    }

    /// The take is sampled at the reference's seconds-per-bar rather than into the same bar
    /// count, so a take that runs long draws longer than the bed it sits on.
    private func loadTakeWaveform(for line: DubLine) async {
        let takeURL = pack.takeURL(for: line)

        guard isRecorded(line),
              let takeDuration = await AudioFileManager.shared.getAudioDurationAsync(from: takeURL),
              takeDuration > 0 else {
            takeSamples = []
            return
        }

        let buckets = WaveformScaling.bucketCount(
            forDuration: takeDuration,
            referenceDuration: line.duration,
            referenceBuckets: Self.referenceBuckets
        )

        takeSamples = await WaveformSampler.shared.samples(from: takeURL, buckets: buckets)
    }

    /// Files a metering tick against the moment it was sampled.
    ///
    /// Published normalised, because that is what `WaveformSampler` hands back for the
    /// finished take. The two have to be the same measurement on the same scale or the shape
    /// jumps when the mic closes.
    private func appendToLiveTrace(_ peak: Float) {
        guard isRecording else { return }
        guard trace.add(peak, at: CACurrentMediaTime() - traceStartedAt) else { return }

        liveTrace = trace.normalizedBars
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
        stopEverything()
        currentLineIndex = index
        reloadWaveformsForCurrentLine()
    }


    func goToNextLine() {
        guard currentLineIndex < pack.lines.count - 1 else { return }
        stopEverything()
        currentLineIndex += 1
        reloadWaveformsForCurrentLine()
        SoundManager.shared.play(.mechanicalClick)
        HapticManager.shared.light()
    }

    func goToPreviousLine() {
        guard currentLineIndex > 0 else { return }
        stopEverything()
        currentLineIndex -= 1
        reloadWaveformsForCurrentLine()
        SoundManager.shared.play(.mechanicalClick)
        HapticManager.shared.light()
    }

    /// Jumps to the first line without a take, or stays put if the scene is fully dubbed.
    func jumpToFirstUnrecordedLine() {
        if let index = pack.lines.firstIndex(where: { !recordedSlugs.contains($0.slug) }) {
            currentLineIndex = index
            reloadWaveformsForCurrentLine()
        }
    }

    /// Fire-and-forget refresh, so callers stay synchronous.
    private func reloadWaveformsForCurrentLine() {
        let line = currentLine
        liveTrace = []
        // The card belongs to the take that was just performed, not to the next line.
        latestScore = line.flatMap { score(for: $0) }
        Task { await loadWaveforms(for: line) }
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
    }

    // MARK: - Reference Preview

    /// Plays the pack's own recording of the current line, so the user hears the delivery
    /// they're matching. Never runs while the mic is open.
    func toggleReferencePreview() {
        guard let line = currentLine else { return }

        if isPreviewingReference {
            referencePlayer.stop()
            return
        }

        guard !isRecording else { return }

        do {
            try referencePlayer.loadAudio(from: pack.referenceAudioURL(for: line))
            referencePlayer.play()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Plays back the user's own take for this line, if there is one.
    func playCurrentTake() {
        guard let line = currentLine, isRecorded(line), !isRecording else { return }

        if isPreviewingReference {
            referencePlayer.stop()
            return
        }

        do {
            try referencePlayer.loadAudio(from: pack.takeURL(for: line))
            referencePlayer.play()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        // A second press during the slate is a change of mind, not a stop: nothing has been
        // recorded yet, so cancel the count rather than trying to stop a mic that never opened.
        if slate.isRunning {
            cancelCountdown()
            return
        }

        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        // The backing track is never playing here. Anything through the speaker would
        // bleed straight into the take.
        referencePlayer.stop()
        monitorPlayer.stop()
        scenePlayer.stop()

        recorder.requestPermission { [weak self] granted in
            guard let self else { return }
            self.hasRecordingPermission = granted

            guard granted else {
                self.showPermissionAlert = true
                AnalyticsManager.shared.trackPermissionDenied()
                return
            }

            guard self.recorder.canStartRecording() else { return }

            self.runCountdownThenRecord()
        }
    }

    /// Slate, then roll: three tones, the mic opening as the last one releases.
    private func runCountdownThenRecord() {
        slate.run(
            onBeat: { [weak self] beat in self?.countdown = beat },
            thenRecord: { [weak self] in self?.beginRecording() }
        )
    }

    private func cancelCountdown() { slate.cancel() }

    private func beginRecording() {
        guard recorder.canStartRecording(), let line = currentLine else { return }

        do {
            SoundManager.shared.setMicrophoneOpen(true)
            liveTrace = []
            takeSamples = []

            // Fixed before the mic opens, so every tick that follows lands on the same axis.
            let lineDuration = line.duration
            trace = LiveTrace(
                barDuration: lineDuration > 0
                    ? lineDuration / Double(Self.referenceBuckets)
                    : Self.fallbackTraceBarDuration,
                // The take cannot outrun the line any more, so the trace cannot outrun the
                // rail either. The overrun allowance is only for a line of unknown length.
                maximumBars: lineDuration > 0
                    ? Self.referenceBuckets
                    : Self.referenceBuckets * WaveformScaling.maxOverrun
            )

            // Any headphone reference has to be decoded and its engine warmed before the
            // common deadline is chosen. Loading it afterwards can consume the whole runway
            // and turn a scheduled cue into another late immediate start.
            let hasPreparedMonitor = prepareHeadphoneMonitorIfAllowed()

            // `AudioRecorder` chooses this future boundary only after audio-session setup, so
            // variable route activation cannot consume the scheduling runway. It publishes
            // the matching host time synchronously before `isRecording` changes.
            let leadIn = Self.recordingStartLeadIn
            // The recorder caps the audio itself; the UI task waits through the scheduling
            // runway and then saves the completed file.
            _ = try recorder.startRecording(
                maxDuration: lineDuration > 0 ? lineDuration : nil,
                startDelay: leadIn,
                onScheduled: { [weak self] hostTime in
                    self?.recordingAnchor = DubPlaybackAnchor(
                        offset: line.startTime,
                        hostTime: hostTime
                    )
                }
            )
            traceStartedAt = CACurrentMediaTime() + leadIn
            scheduleAutoStop(after: lineDuration > 0 ? lineDuration + leadIn : 0)

            if hasPreparedMonitor {
                monitorPlayer.play(atHostTime: recordingAnchor?.hostTime)
            }
            HapticManager.shared.heavy()
        } catch {
            recordingAnchor = nil
            SoundManager.shared.setMicrophoneOpen(false)
            errorMessage = error.localizedDescription
            SoundManager.shared.play(.errorThunk)
        }
    }

    /// A line with no usable duration still needs bars, or the trace never draws at all.
    private static let fallbackTraceBarDuration: TimeInterval = 0.05

    /// Ends the take when the line does.
    ///
    /// A dub take is a replacement for a fixed stretch of film, so asking the performer to
    /// judge the end themselves only produces takes that have to be trimmed later. The
    /// recorder has already been told to stop on the audio clock. This is what tells the
    /// screen, saves the file, and hands the user back their transport.
    private func scheduleAutoStop(after duration: TimeInterval) {
        autoStopTask?.cancel()
        guard duration > 0 else { return }

        autoStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, let self, self.isRecording else { return }

            self.stopRecording()
        }
    }

    private func cancelAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = nil
    }

    // MARK: - Headphone Monitoring

    /// Loads the optional headphone reference before the common capture deadline is chosen.
    ///
    /// Only ever on headphones: the same audio through the speaker would be recorded along
    /// with the voice. Returns whether a warmed monitor is ready to be scheduled alongside
    /// the microphone and picture.
    private func prepareHeadphoneMonitorIfAllowed() -> Bool {
        HeadphoneMonitor.shared.refresh()

        guard HeadphoneMonitor.shared.shouldPlayOriginalWhileRecording,
              let line = currentLine else { return false }

        do {
            try monitorPlayer.loadAudio(from: pack.referenceAudioURL(for: line))
            monitorPlayer.isLooping = true
            return true
        } catch {
            // Monitoring is optional; keep the take available without it.
            print("⚠️ Headphone monitor unavailable: \(error)")
            return false
        }
    }

    private func stopRecording() {
        cancelAutoStop()
        recordingAnchor = nil

        guard recorder.canStopRecording(), let line = currentLine else { return }
        guard let temporaryURL = recorder.stopRecording() else {
            monitorPlayer.stop()
            SoundManager.shared.setMicrophoneOpen(false)
            errorMessage = Strings.Error.failedToStopRecording
            return
        }

        monitorPlayer.stop()
        SoundManager.shared.setMicrophoneOpen(false)
        SoundManager.shared.play(.tapeStop)
        HapticManager.shared.heavy()

        let destination = pack.takeURL(for: line)

        Task {
            do {
                let duration = await AudioFileManager.shared.getAudioDurationAsync(from: temporaryURL) ?? 0

                let lineDuration = line.duration

                try await Task.detached(priority: .userInitiated) {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: temporaryURL, to: destination)

                    // The recorder already caps a take at the line's length; this is what
                    // makes a take the performer cut short come out the same length too, so
                    // every take on this line is exactly the stretch of film it replaces.
                    try DubAudioLoader.normalizeDuration(ofFileAt: destination, to: lineDuration)
                }.value

                recordedSlugs.insert(line.slug)

                // The file just changed on disk; anything cached for it is the old take.
                await WaveformSampler.shared.invalidate(destination)
                scenePlayer.invalidateVoice(for: line)
                await loadTakeWaveform(for: line)
                liveTrace = []

                HapticManager.shared.success()
                AnalyticsManager.shared.trackDubLineRecorded(lineIndex: line.index, duration: duration)

                await scoreTake(for: line)
            } catch {
                errorMessage = error.localizedDescription
            }
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
    private func scoreTake(for line: DubLine) async {
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
        stopEverything()
        await scenePlayer.prepare(pack: pack, mode: mode)
        scenePlayer.play(from: offset)
    }

    func stopEverything() {
        cancelCountdown()
        cancelAutoStop()
        recordingAnchor = nil

        if isRecording {
            recorder.cancelRecording()
            SoundManager.shared.setMicrophoneOpen(false)
        }
        monitorPlayer.stop()
        referencePlayer.stop()
        scenePlayer.stop()
    }

    // MARK: - Export

    func export() async {
        guard hasAnyTake else {
            errorMessage = Strings.Dub.Error.nothingRecorded
            return
        }

        stopEverything()
        isExporting = true
        exportProgress = 0
        SoundManager.shared.play(.reelSpinUp)
        defer { isExporting = false }

        do {
            let url = try await DubMixer.shared.export(pack: pack) { [weak self] stage, value in
                Task { @MainActor [weak self] in
                    self?.exportStage = stage
                    self?.exportProgress = Self.overallProgress(stage: stage, value: value)
                }
            }

            exportedURL = url
            SoundManager.shared.play(.projectorChime)
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            SoundManager.shared.play(.errorThunk)
            HapticManager.shared.error()
        }
    }

    /// Weighted so the bar moves at a believable pace: mixing is fast, video is the long part.
    private static func overallProgress(stage: DubExportStage, value: Double) -> Double {
        switch stage {
        case .mixingAudio: return value * 0.25
        case .renderingVideo: return 0.25 + value * 0.65
        case .finishing: return 0.90 + value * 0.10
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        stopEverything()
        recorder.cleanup()
        referencePlayer.cleanup()
        monitorPlayer.cleanup()
        scenePlayer.cleanup()
    }
}
