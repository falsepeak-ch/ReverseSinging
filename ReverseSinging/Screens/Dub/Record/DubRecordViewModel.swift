//
//  DubRecordViewModel.swift
//  ReverseSinging
//
//  The recording bay: slate, microphone, live trace, headphone monitor, booth camera, and the
//  scene rolling under the take
//

import SwiftUI
import Combine
import QuartzCore
import AVFoundation
import DubAudio

/// Drives the record screen.
///
/// What a take leaves behind, the file, its footage and its score, is handed to `session`,
/// because the pack screen and playback read it too. Everything that only exists while the bay
/// is open lives here: the microphone, the slate, the trace being drawn, the camera.
@MainActor
final class DubRecordViewModel: ObservableObject {

    let session: DubSessionViewModel

    var pack: DubPack { session.pack }
    var currentLine: DubLine? { session.currentLine }

    // MARK: - Recording

    @Published private(set) var isRecording = false
    /// Beats left in the slate, 3...1, or nil when no countdown is running.
    @Published private(set) var countdown: Int?
    @Published private(set) var recordingLevel: Float = 0
    @Published private(set) var recordingDuration: TimeInterval = 0
    /// The deadline at which both microphone sample zero and the line's first video frame
    /// begin. Published so the scene picture can be scheduled before the deadline.
    @Published private(set) var recordingAnchor: DubPlaybackAnchor?
    @Published var hasRecordingPermission = false
    @Published var showPermissionAlert = false

    // MARK: - Booth Cam

    /// The front camera that rolls beside a take, when the user has asked for it.
    let booth = BoothRecorder()

    /// Shown the first time someone reaches for the camera key, never on arrival.
    @Published var isBoothPrimerPresented = false

    // MARK: - Scene Picture

    /// The scene video under the take. Its changes are passed on as this model's own, so the
    /// screen redraws when the video opens.
    let scenePicture = DubScenePictureViewModel()

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
        barDuration: DubRecordViewModel.fallbackTraceBarDuration,
        maximumBars: DubRecordViewModel.referenceBuckets * WaveformScaling.maxOverrun
    )
    /// When the mic actually opened, on the media clock, so a bar index comes from the moment
    /// a level was sampled rather than from how many levels have arrived.
    private var traceStartedAt: CFTimeInterval = 0

    // MARK: - Services

    private let recorder = AudioRecorder()
    /// Feeds the reference to the performer's headphones during a take. Deliberately not the
    /// session's reference player: that one drives `isPreviewingReference`, which this screen
    /// reads to decide whether the user is listening or performing, and the two must not be
    /// confused for one another.
    private let monitorPlayer = AudioPlayer()

    private let slate = RecordSlate()
    private var autoStopTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Scheduling runway shared by AVAudioRecorder and AVPlayer. Starting either immediately
    /// makes the second API call late by construction; a short future deadline lets both
    /// subsystems commit before sample/frame zero.
    private static let recordingStartLeadIn: TimeInterval = 0.15

    // MARK: - Init

    init(session: DubSessionViewModel) {
        self.session = session
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

        scenePicture.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Screen

    func onAppear() {
        scenePicture.configure(with: pack)
        if let line = currentLine { scenePicture.show(line) }
        AnalyticsManager.shared.trackScreenViewed(screenName: "DubRecord")
        #if DEBUG
        // The `boothCam` slot on the product page. The primer, not the monitor:
        // a simulator has no front camera to preview.
        if ScreenshotMode.isActive, ScreenshotMode.destination?.presentsBoothPrimer == true {
            isBoothPrimerPresented = true
        }
        #endif
    }

    func onDisappear() {
        scenePicture.tearDown()
        stopBooth()
        stop()
    }

    /// The session moved to another line, from this screen or from anywhere else.
    func lineDidChange() {
        reloadWaveformsForCurrentLine()
        // Park the picture on whichever line is up next.
        guard let line = currentLine else { return }
        scenePicture.show(line)
    }

    /// Roll the picture whenever the line is being heard or performed, so the user is always
    /// dubbing to something rather than to a frozen frame.
    func previewDidChange(isPreviewing: Bool) {
        guard let line = currentLine else { return }
        isPreviewing ? scenePicture.play(line) : scenePicture.stop(returningTo: line)
    }

    /// Schedule the first frame on the microphone's exact future start boundary. Starting
    /// the recorder and only then reacting here used to bake the asynchronous video seek
    /// into every take as leading silence; that delay was still present on playback.
    func recordingAnchorDidChange(_ anchor: DubPlaybackAnchor?) {
        guard let anchor, let line = currentLine else { return }
        scenePicture.play(line, at: anchor, loop: line.duration <= 0)
    }

    func recordingDidChange(isRecording: Bool) {
        guard let line = currentLine else { return }
        if !isRecording { scenePicture.stop(returningTo: line) }
    }

    func boothPreferenceDidChange(isOn: Bool) {
        DubTips.noteBooth(isOn: isOn)
    }

    // MARK: - Transport

    var isOnLastLine: Bool {
        session.currentLineIndex >= pack.lines.count - 1
    }

    var canGoToPreviousLine: Bool {
        session.currentLineIndex > 0 && !isRecording
    }

    func canPlayTake(of line: DubLine) -> Bool {
        session.isRecorded(line) && !isRecording
    }

    /// How the last take scored, or nothing at all.
    ///
    /// Hidden while the mic is open: mid-take, the previous attempt's verdict is a distraction
    /// from the line being performed, and the number it shows is about to be replaced anyway.
    var showsScoreCard: Bool {
        session.isScoringEnabled && session.latestScore != nil && !isRecording
    }

    func goToPreviousLine() {
        guard session.currentLineIndex > 0 else { return }
        stop()
        session.goToPreviousLine()
    }

    func goToNextLine() {
        guard session.currentLineIndex < pack.lines.count - 1 else { return }
        stop()
        session.goToNextLine()
    }

    /// Never over an open mic: the reference would be recorded along with the voice.
    func toggleReferencePreview() {
        guard session.isPreviewingReference || !isRecording else { return }
        session.toggleReferencePreview()
    }

    func playCurrentTake() {
        guard !isRecording else { return }
        session.playCurrentTake()
    }

    // MARK: - Display

    /// While the mic is open this is the live trace; once a take exists it is that take's
    /// real shape, so the comparison survives past the end of the recording.
    ///
    /// Both fill the rail, because a take is always the length of the line it replaces.
    var takeOverlay: [Float]? {
        if isRecording {
            return liveTrace.isEmpty ? nil : liveTrace
        }
        return takeSamples.isEmpty ? nil : takeSamples
    }

    /// The playhead: where the preview has got to, or, while the mic is open, where the take
    /// has. During a take it is the only thing on screen that says *where in the line you are*,
    /// which is what lets a performer see the original's run-up coming rather than talking
    /// straight over it.
    func waveformProgress(for line: DubLine) -> Double? {
        if isRecording {
            guard line.duration > 0 else { return nil }
            return min(1, recordingDuration / line.duration)
        }
        return session.isPreviewingReference ? session.previewProgress : nil
    }

    func pacingFraction(for line: DubLine) -> Double {
        guard isRecording, line.duration > 0 else { return 0 }
        return min(1.0, recordingDuration / line.duration)
    }

    func isOverLength(_ line: DubLine) -> Bool {
        isRecording && line.duration > 0 && recordingDuration > line.duration
    }

    func timerText(for line: DubLine) -> String {
        let elapsed = isRecording ? recordingDuration : 0
        return String(format: "%05.2f / %05.2f", elapsed, line.duration)
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

        guard session.isRecorded(line),
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

    /// Fire-and-forget refresh, so callers stay synchronous.
    private func reloadWaveformsForCurrentLine() {
        let line = currentLine
        liveTrace = []
        Task { await loadWaveforms(for: line) }
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

    // MARK: - Booth Lifecycle

    /// Brings the preview up if the user has asked for it. Called when the record screen
    /// appears, so the camera is never live while they are somewhere else in the app.
    func startBoothIfEnabled() async {
        guard BoothCamPreference.shared.isEnabled else { return }
        await booth.start()
    }

    /// Drops the preview and any clip in flight.
    func stopBooth() {
        booth.stop()
    }

    /// Turns filming off for the rest of the session without leaving the take.
    ///
    /// The preference itself is what the camera key in the HUD writes, so the choice carries
    /// to the next line and the next scene, which is what someone reaching for it wants.
    func setBoothEnabled(_ enabled: Bool) async {
        BoothCamPreference.shared.isEnabled = enabled

        if enabled {
            await booth.start()
        } else {
            booth.stop()
        }
    }

    /// The camera key in the HUD.
    func toggleBooth() {
        if BoothCamPreference.shared.isEnabled {
            Task { await setBoothEnabled(false) }
        } else if BoothCamPreference.shared.hasSeenPrimer, BoothRecorder.cameraPermission == .granted {
            Task { await setBoothEnabled(true) }
        } else {
            // Either the case has never been made, or the system said no and the user
            // needs to be told why nothing happened.
            isBoothPrimerPresented = true
        }
    }

    /// The primer's yes, once the system has had its say too.
    func boothPrimerDidEnable() {
        Task { await setBoothEnabled(true) }
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
        monitorPlayer.stop()
        session.stopPlayback()

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
                    guard let self else { return }
                    self.recordingAnchor = DubPlaybackAnchor(
                        offset: line.startTime,
                        hostTime: hostTime
                    )
                    // The booth rolls on the microphone's deadline, not on this call. Frames
                    // that arrive before it are dropped rather than written, so the clip and
                    // the take share sample zero however long the camera took to deliver.
                    self.booth.startTake(
                        anchorHostTime: hostTime,
                        duration: lineDuration,
                        to: self.pack.boothTakeURL(for: line)
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
            session.errorMessage = error.localizedDescription
            SoundManager.shared.play(.errorThunk)
            CrashReporter.shared.record(error, context: "dub.record_start")
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

        guard recorder.canStopRecording(), let line = currentLine else {
            booth.cancelTake()
            return
        }
        guard let temporaryURL = recorder.stopRecording() else {
            booth.cancelTake()
            monitorPlayer.stop()
            SoundManager.shared.setMicrophoneOpen(false)
            session.errorMessage = Strings.Error.failedToStopRecording
            return
        }

        // Closed on its own clock the moment the line ran out; this is what collects the
        // result. A clip that never got a frame leaves no file, so the line simply has no
        // footage rather than an empty one.
        Task {
            let clip = await booth.finishTake()
            session.setBoothTake(clip != nil, for: line)
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

                session.markRecorded(line)
                // There is a dub to hear now, which is what the playback tip waits for.
                DubTips.hasRecordedATake = true

                // The file just changed on disk; anything cached for it is the old take.
                await WaveformSampler.shared.invalidate(destination)
                session.scenePlayer.invalidateVoice(for: line)
                await loadTakeWaveform(for: line)
                liveTrace = []

                HapticManager.shared.success()
                AnalyticsManager.shared.trackDubLineRecorded(lineIndex: line.index, duration: duration)

                await session.scoreTake(for: line)
            } catch {
                session.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Stopping

    /// Closes the microphone, the slate and the headphone monitor, then silences the session.
    func stop() {
        cancelCountdown()
        cancelAutoStop()
        recordingAnchor = nil

        if isRecording {
            recorder.cancelRecording()
            booth.cancelTake()
            SoundManager.shared.setMicrophoneOpen(false)
        }
        monitorPlayer.stop()
        session.stopPlayback()
    }

    func cleanup() {
        stop()
        recorder.cleanup()
        monitorPlayer.cleanup()
    }
}
