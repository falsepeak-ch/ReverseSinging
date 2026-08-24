//
//  DubViewModel.swift
//  ReverseSinging
//
//  Drives one dub session: line-by-line recording, scene playback, export
//

import SwiftUI
import Combine
import QuartzCore

@MainActor
final class DubViewModel: ObservableObject {

    // MARK: - Session

    let pack: DubPack

    @Published var currentLineIndex: Int = 0
    @Published private(set) var recordedSlugs: Set<String> = []

    // MARK: - Recording

    @Published private(set) var isRecording = false
    /// Beats left in the slate, 3...1, or nil when no countdown is running.
    @Published private(set) var countdown: Int?
    @Published private(set) var recordingLevel: Float = 0
    @Published private(set) var recordingDuration: TimeInterval = 0
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

    // MARK: - Services

    private let recorder = AudioRecorder()
    private let referencePlayer = AudioPlayer()
    /// Feeds the reference to the performer's headphones during a take. Deliberately not
    /// `referencePlayer`: that one drives `isPreviewingReference`, which the record screen
    /// reads to decide whether the user is listening or performing, and the two must not be
    /// confused for one another.
    private let monitorPlayer = AudioPlayer()
    let scenePlayer = DubPlayer()

    private var countdownTask: Task<Void, Never>?
    private var autoStopTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(pack: DubPack) {
        self.pack = pack
        refreshRecordedSlugs()
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

        // Collected separately from the published level: the level drives the meter and is
        // replaced each tick, whereas the trace has to accumulate to draw a shape.
        recorder.$recordingLevel
            .sink { [weak self] level in
                self?.appendToLiveTrace(level)
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
    private func appendToLiveTrace(_ level: Float) {
        guard isRecording else { return }
        guard trace.add(level, at: CACurrentMediaTime() - traceStartedAt) else { return }

        liveTrace = trace.bars
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
        if countdownTask != nil {
            cancelCountdown()
            return
        }

        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        // The backing track is never playing here — anything through the speaker would
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
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await RecordCountdown.run { beat in
                    self.countdown = beat
                    HapticManager.shared.light()
                }
            } catch {
                // Cancelled — `cancelCountdown` has already cleared the state.
                return
            }

            self.countdown = nil
            self.countdownTask = nil
            self.beginRecording()
        }
    }

    private func cancelCountdown() {
        // Called from every teardown path, so it has to be silent when no count is running.
        guard let task = countdownTask else { return }

        task.cancel()
        countdownTask = nil
        countdown = nil
        HapticManager.shared.light()
    }

    private func beginRecording() {
        guard recorder.canStartRecording() else { return }

        do {
            SoundManager.shared.setMicrophoneOpen(true)
            liveTrace = []
            takeSamples = []

            // Fixed before the mic opens, so every tick that follows lands on the same axis.
            let lineDuration = currentLine?.duration ?? 0
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

            // The recorder caps the audio itself; this only tells the rest of the screen the
            // take is over, and writes it to disk.
            _ = try recorder.startRecording(maxDuration: lineDuration > 0 ? lineDuration : nil)
            traceStartedAt = CACurrentMediaTime()
            scheduleAutoStop(after: lineDuration)

            startHeadphoneMonitorIfAllowed()
            HapticManager.shared.heavy()
        } catch {
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
    /// recorder has already been told to stop on the audio clock — this is what tells the
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

    /// Plays the reference into the performer's headphones for the length of the take.
    ///
    /// Only ever on headphones: the same audio through the speaker would be recorded along
    /// with the voice. It loops for the same reason the picture does — a take routinely runs
    /// past the line, and a monitor that stops halfway is worse than no monitor.
    private func startHeadphoneMonitorIfAllowed() {
        HeadphoneMonitor.shared.refresh()

        guard HeadphoneMonitor.shared.shouldPlayOriginalWhileRecording,
              let line = currentLine else { return }

        do {
            try monitorPlayer.loadAudio(from: pack.referenceAudioURL(for: line))
            monitorPlayer.isLooping = true
            monitorPlayer.play()
        } catch {
            // Not worth interrupting a take that is already running for.
            print("⚠️ Headphone monitor unavailable: \(error)")
        }
    }

    private func stopRecording() {
        cancelAutoStop()

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
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteTake(for line: DubLine) {
        let url = pack.takeURL(for: line)
        try? FileManager.default.removeItem(at: url)
        recordedSlugs.remove(line.slug)

        Task { await WaveformSampler.shared.invalidate(url) }
        scenePlayer.invalidateVoice(for: line)
        if line.id == currentLine?.id { takeSamples = [] }

        HapticManager.shared.light()
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
                Task { @MainActor in
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
