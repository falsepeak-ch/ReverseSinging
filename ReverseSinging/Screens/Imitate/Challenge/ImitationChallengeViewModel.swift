//
//  ImitationChallengeViewModel.swift
//  ReverseSinging
//
//  One sound: hear it, imitate it, get the verdict, make the video
//

import Combine
import DubAudio
import DubScoring
import SwiftUI

@MainActor
final class ImitationChallengeViewModel: ObservableObject {

    enum Phase: Equatable {
        /// Waiting for an attempt: listen as often as you like.
        case ready
        /// The 3-2-1 slate.
        case countingIn
        /// The mic is open.
        case recording
        /// The attempt is being measured.
        case scoring
        /// The verdict is on screen.
        case result
    }

    /// Which clip the player has loaded, so the right transport shows as playing.
    enum Clip {
        case reference, take
    }

    let sound: ImitationSound
    let booth = BoothRecorder()

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var countdown: Int?
    @Published private(set) var score: ImitationScore?
    @Published private(set) var verdict: ImitationVerdict?
    @Published private(set) var isNewBest = false
    @Published private(set) var referenceBars: [Float] = []
    @Published private(set) var playingClip: Clip?
    /// Seeds the confetti on screen and in the video, so both throw the same burst.
    @Published private(set) var confettiSeed: UInt64 = 0
    /// When the confetti was thrown: the moment the stamp landed on a pass.
    @Published private(set) var confettiStart: Date?

    @Published var isBoothPrimerPresented = false
    @Published var showPermissionAlert = false
    @Published var errorMessage: String?

    /// 0...1 while the video renders, nil otherwise.
    @Published private(set) var exportProgress: Double?
    /// The finished video, which opens the share sheet.
    @Published var exportedURL: URL?

    private let recorder = AudioRecorder()
    private let player = AudioPlayer()
    private let slate = RecordSlate()
    private let progressStore: ImitationProgressStore
    private var autoStopTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var hasBoothClip = false

    /// Gives the performer room to breathe in and trail off, without making them wait out a
    /// long silence after a half-second bark.
    var maximumTakeDuration: TimeInterval {
        max(2, sound.duration * 1.6 + 0.8)
    }

    /// The same runway the dub recorder uses between choosing the start and sample zero, so
    /// the camera can be told the exact instant too.
    private static let recordingStartLeadIn: TimeInterval = 0.15

    init(sound: ImitationSound, progressStore: ImitationProgressStore = .shared) {
        self.sound = sound
        self.progressStore = progressStore

        // The meter and the playhead live on these; the screen redraws with them.
        for publisher in [recorder.objectWillChange, player.objectWillChange, booth.objectWillChange] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
        player.$isPlaying
            .removeDuplicates()
            .sink { [weak self] isPlaying in if !isPlaying { self?.playingClip = nil } }
            .store(in: &cancellables)
    }

    // MARK: - Derived

    var level: Float { recorder.recordingLevel }
    var recordingElapsed: TimeInterval { recorder.recordingDuration }
    var playbackProgress: Double {
        player.duration > 0 ? min(1, player.currentTime / player.duration) : 0
    }
    var isBoothEnabled: Bool { BoothCamPreference.shared.isEnabled }
    var isBusy: Bool { phase == .countingIn || phase == .recording || phase == .scoring || exportProgress != nil }

    /// Booth footage of the attempt on screen, to play back under the verdict.
    var boothPlaybackURL: URL? { phase == .result && hasBoothClip ? boothURL : nil }

    private var takeURL: URL {
        AudioFileManager.shared.imitateTakesDirectory().appendingPathComponent("\(sound.id).caf")
    }

    private var boothURL: URL {
        AudioFileManager.shared.imitateBoothDirectory().appendingPathComponent("\(sound.id).mov")
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "ImitateChallenge")
        AnalyticsManager.shared.trackImitateSoundOpened(soundID: sound.id)
        Task { await loadReferenceBars() }
        Task { await startBoothIfEnabled() }
    }

    func onDisappear() {
        slate.cancel()
        cancelAutoStop()
        if recorder.isRecording { recorder.cancelRecording() }
        booth.cancelTake()
        booth.stop()
        player.stop()
    }

    private func loadReferenceBars() async {
        guard let url = sound.url else { return }
        referenceBars = await WaveformSampler.shared.samples(from: url, buckets: 40)
    }

    // MARK: - Listening

    func playReference() {
        guard let url = sound.url else { return }
        play(url, as: .reference)
    }

    func playTake() {
        guard FileManager.default.fileExists(atPath: takeURL.path) else { return }
        play(takeURL, as: .take)
    }

    private func play(_ url: URL, as clip: Clip) {
        guard !isBusy else { return }
        if playingClip == clip {
            player.stop()
            playingClip = nil
            return
        }
        do {
            try player.loadAudio(from: url)
            player.isLooping = false
            player.play()
            playingClip = clip
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Booth

    private func startBoothIfEnabled() async {
        guard BoothCamPreference.shared.isEnabled else { return }
        await booth.start()
    }

    /// The camera key in the header. Same rules as the dub recorder's: the app makes its
    /// case once before iOS asks.
    func toggleBooth() {
        guard !isBusy else { return }
        if BoothCamPreference.shared.isEnabled {
            BoothCamPreference.shared.isEnabled = false
            booth.stop()
            objectWillChange.send()
        } else if BoothCamPreference.shared.hasSeenPrimer, BoothRecorder.cameraPermission == .granted {
            boothPrimerDidEnable()
        } else {
            isBoothPrimerPresented = true
        }
    }

    func boothPrimerDidEnable() {
        BoothCamPreference.shared.isEnabled = true
        objectWillChange.send()
        Task { await booth.start() }
    }

    // MARK: - Recording

    /// The big button: start the count, or stop an attempt early.
    func toggleRecording() {
        switch phase {
        case .countingIn:
            slate.cancel()
            phase = score == nil ? .ready : .result
        case .recording:
            stopRecording()
        case .ready, .result:
            startRecording()
        case .scoring:
            break
        }
    }

    private func startRecording() {
        guard exportProgress == nil else { return }
        player.stop()
        playingClip = nil

        recorder.requestPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.showPermissionAlert = true
                AnalyticsManager.shared.trackPermissionDenied()
                return
            }
            guard self.recorder.canStartRecording() else { return }

            self.phase = .countingIn
            self.confettiStart = nil
            self.slate.run(
                onBeat: { [weak self] beat in self?.countdown = beat },
                thenRecord: { [weak self] in self?.beginRecording() }
            )
        }
    }

    private func beginRecording() {
        // The count ran out while the user was in another app, which can't open the mic.
        guard AppActivity.canOpenMicrophone, recorder.canStartRecording() else {
            phase = score == nil ? .ready : .result
            return
        }

        let duration = maximumTakeDuration
        let boothURL = boothURL
        try? FileManager.default.removeItem(at: boothURL)
        hasBoothClip = false

        do {
            SoundManager.shared.setMicrophoneOpen(true)
            _ = try recorder.startRecording(
                maxDuration: duration,
                startDelay: Self.recordingStartLeadIn,
                onScheduled: { [weak self] hostTime in
                    // The booth rolls on the microphone's deadline, so the clip and the take
                    // share sample zero however long the camera takes to deliver.
                    self?.booth.startTake(anchorHostTime: hostTime, duration: duration, to: boothURL)
                }
            )
            phase = .recording
            HapticManager.shared.heavy()
            scheduleAutoStop(after: duration + Self.recordingStartLeadIn)
        } catch {
            SoundManager.shared.setMicrophoneOpen(false)
            phase = score == nil ? .ready : .result
            errorMessage = error.localizedDescription
            SoundManager.shared.play(.errorThunk)
            CrashReporter.shared.record(error, context: "imitate.record_start")
        }
    }

    private func scheduleAutoStop(after duration: TimeInterval) {
        cancelAutoStop()
        autoStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, let self, self.phase == .recording else { return }
            self.stopRecording()
        }
    }

    private func cancelAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = nil
    }

    private func stopRecording() {
        cancelAutoStop()
        SoundManager.shared.setMicrophoneOpen(false)

        guard let temporaryURL = recorder.stopRecording() else {
            booth.cancelTake()
            phase = score == nil ? .ready : .result
            errorMessage = Strings.Error.failedToStopRecording
            return
        }

        SoundManager.shared.play(.tapeStop)
        HapticManager.shared.heavy()
        phase = .scoring

        let destination = takeURL
        Task {
            hasBoothClip = await booth.finishTake() != nil
            do {
                try await Self.move(temporaryURL, to: destination)
                await WaveformSampler.shared.invalidate(destination)
                await judge(take: destination)
            } catch {
                phase = score == nil ? .ready : .result
                errorMessage = error.localizedDescription
                CrashReporter.shared.record(error, context: "imitate.save_take")
            }
        }
    }

    @concurrent
    private static func move(_ source: URL, to destination: URL) async throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    // MARK: - Scoring

    private func judge(take: URL) async {
        guard let referenceURL = sound.url else { return }
        let measured = await Self.measure(take: take, reference: referenceURL) ?? .silent

        confettiSeed = UInt64.random(in: 1...UInt64.max)
        verdict = ImitationVerdict.forGrade(measured.grade, seed: Int(confettiSeed % 997))
        score = measured
        isNewBest = progressStore.record(measured.overall, for: sound)
        phase = .result

        if verdict?.celebrates == true {
            HapticManager.shared.success()
        } else {
            HapticManager.shared.error()
        }

        AnalyticsManager.shared.trackImitateAttemptScored(
            soundID: sound.id,
            score: measured.overall,
            grade: measured.grade.rawValue,
            withBooth: hasBoothClip
        )
    }

    /// The stamp hit the desk: the thud, and confetti if it was a pass.
    func stampDidLand() {
        guard let verdict else { return }
        SoundManager.shared.play(verdict.celebrates ? .clapperSnap : .errorThunk)
        HapticManager.shared.heavy()
        if verdict.celebrates { confettiStart = Date() }
    }

    @concurrent
    private static func measure(take: URL, reference: URL) async -> ImitationScore? {
        ImitationScorer.score(takeURL: take, referenceURL: reference)
    }

    // MARK: - Video

    func makeVideo() {
        guard let score, let verdict, let referenceURL = sound.url, exportProgress == nil else { return }
        player.stop()
        playingClip = nil
        exportProgress = 0

        let reel = ImitationReel(
            soundName: sound.name,
            emoji: sound.emoji,
            referenceURL: referenceURL,
            takeURL: takeURL,
            boothURL: hasBoothClip ? boothURL : nil,
            score: score,
            verdict: verdict,
            seed: confettiSeed,
            artworkName: sound.artworkName
        )

        Task {
            let work = LongRunningWork(name: "imitate.export")
            defer { work.end() }
            do {
                // The render takes seconds and the screen can't be left without cancelling it,
                // so holding the model for that long is fine.
                let url = try await ImitationReelRenderer.render(reel) { value in
                    Task { @MainActor in
                        guard let current = self.exportProgress else { return }
                        self.exportProgress = max(current, value)
                    }
                }
                exportProgress = nil
                exportedURL = url
                SoundManager.shared.play(.projectorChime)
                AnalyticsManager.shared.trackImitateVideoExported(
                    soundID: sound.id, score: score.overall, withBooth: reel.boothURL != nil
                )
            } catch {
                exportProgress = nil
                errorMessage = Strings.Imitate.exportFailed
                CrashReporter.shared.record(error, context: "imitate.export")
            }
        }
    }
}
