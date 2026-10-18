//
//  GameDubRoundViewModel.swift
//  DubloonGame
//
//  A scene, played line by line: the session and the recorder, and what the stage shows.
//

import SwiftUI
import Combine
import DubScoring
import DubCompositing

/// Owns a scene's `DubSessionViewModel` and its `DubRecordViewModel`, the same two the iPhone
/// app's recorder uses, and adds what the game needs on top: when a score is being revealed,
/// and what the host makes of it.
@MainActor
final class GameDubRoundViewModel: ObservableObject {

    let session: DubSessionViewModel
    let recorder: DubRecordViewModel

    /// The score being revealed on the monitor, until the line changes or the mic opens again.
    @Published private(set) var reveal: DubLineScore?
    @Published var playbackMode: DubPlaybackMode?
    /// The "before you share" notice, shown before every export.
    @Published var isShareNoticePresented = false
    /// 0...1 while a video renders, nil otherwise.
    @Published private(set) var exportProgress: Double?
    @Published var exportedURL: URL?

    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false
    /// When the mic was last asked to open on the current line. Only a score measured after
    /// it is a result of this visit; anything older is what the session remembers about the
    /// line, which it republishes on every line change.
    private var takeStartedAt: Date?

    init(pack: DubPack) {
        session = DubSessionViewModel(pack: pack)
        recorder = DubRecordViewModel(session: session)

        for publisher in [session.objectWillChange, recorder.objectWillChange] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
        session.$latestScore
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] score in
                guard let self, let score, let since = self.takeStartedAt,
                      score.slug == self.session.currentLine?.slug,
                      score.measuredAt >= since else { return }
                self.takeStartedAt = nil
                self.reveal = score
            }
            .store(in: &cancellables)
    }

    var pack: DubPack { session.pack }
    var line: DubLine? { session.currentLine }
    var lineNumber: Int { session.currentLineIndex + 1 }
    var isRecording: Bool { recorder.isRecording }
    var isCountingIn: Bool { recorder.countdown != nil }
    var isOnLastLine: Bool { recorder.isOnLastLine }
    var hasAnyTake: Bool { session.hasAnyTake }

    var secondsLeft: Int? {
        guard let line, recorder.isRecording else { return nil }
        return Int(ceil(max(0, line.duration - recorder.recordingDuration)))
    }

    /// A take has finished and its score has not come back yet.
    var isScoring: Bool {
        takeStartedAt != nil && !recorder.isRecording && recorder.countdown == nil && reveal == nil
            && session.isScoringEnabled
    }

    /// Every line has a take.
    var isSceneDone: Bool { session.recordedCount >= pack.lines.count && !pack.lines.isEmpty }

    /// What the host says now.
    var hostLine: String {
        if isCountingIn { return GameStrings.Round.countIn }
        if isRecording { return GameStrings.Round.dubRecording }
        if isScoring { return GameStrings.Round.scoring }
        if let reveal { return HostScript.result(reveal) }
        if isSceneDone, isOnLastLine { return GameStrings.Round.sceneDone }
        guard let line else { return "" }
        return session.isRecorded(line) ? GameStrings.Round.dubAgain : GameStrings.Round.dubReady(line.character)
    }

    var canPlayTake: Bool { line.map { recorder.canPlayTake(of: $0) } ?? false }

    var verdict: ImitationVerdict? {
        reveal.map { ImitationVerdict.forGrade($0.grade, seed: Int($0.measuredAt.timeIntervalSince1970)) }
    }

    var mood: HostMood {
        if isCountingIn || isRecording { return .listening }
        if let reveal { return reveal.grade.celebrates ? .cheering : .wincing }
        if session.isPreviewingReference { return .idle }
        return .idle
    }

    func characterColor(for line: DubLine) -> Color {
        DubCharacterStyle.color(for: line.character, in: pack.characters)
    }

    // MARK: - Screen

    func onAppear() {
        if !hasStarted {
            hasStarted = true
            let firstLine = session.currentLineIndex
            session.jumpToFirstUnrecordedLine()
            // The recorder loaded the first line's waveforms when it was made; a jump before
            // the screen is up is not seen by its line-change hook, so it is told here.
            if session.currentLineIndex != firstLine { recorder.lineDidChange() }
        }
        recorder.onAppear()
        AnalyticsManager.shared.trackScreenViewed(screenName: "GameDubRound")
    }

    func onDisappear() {
        recorder.onDisappear()
    }

    // MARK: - Play

    func toggleRecording() {
        if !recorder.isRecording {
            reveal = nil
            takeStartedAt = Date()
        }
        recorder.toggleRecording()
    }

    func listen() {
        recorder.toggleReferencePreview()
    }

    func playTake() {
        recorder.playCurrentTake()
    }

    func nextLine() {
        reveal = nil
        takeStartedAt = nil
        recorder.goToNextLine()
    }

    func previousLine() {
        reveal = nil
        takeStartedAt = nil
        recorder.goToPreviousLine()
    }

    func watchDub() {
        recorder.stop()
        playbackMode = .myDub
    }

    // MARK: - Video

    /// The scene as a vertical video for sharing, drawn like a moment from the show: the
    /// player's booth footage on top, the film in the show's monitor under it, the line and the
    /// two waveforms below that. See `GameShowReel`.
    func makeVideo() {
        guard session.hasAnyTake, exportProgress == nil else { return }
        recorder.stop()
        isShareNoticePresented = true
    }

    func confirmVideo() {
        Task { await renderVideo() }
    }

    private func renderVideo() async {
        session.stopPlayback()
        exportProgress = 0
        defer { exportProgress = nil }
        let work = LongRunningWork(name: "game.dub.export")
        defer { work.end() }
        do {
            let url = try await DubMixer.shared.export(
                pack: pack,
                cut: .fullScene,
                frame: .stacked,
                includesBooth: true
            ) { [weak self] stage, value in
                Task { @MainActor [weak self] in
                    // The render is nine tenths of the wait; the mix and the picture are quick.
                    let base: Double = switch stage {
                    case .mixingAudio: 0
                    case .renderingVideo: 0.08
                    case .finishing: 0.95
                    }
                    let span: Double = stage == .renderingVideo ? 0.87 : 0.05
                    self?.exportProgress = min(1, base + span * value)
                }
            }
            exportedURL = url
            GameSFX.play(.fanfare)
            HapticManager.shared.success()
        } catch {
            session.errorMessage = error.localizedDescription
            HapticManager.shared.error()
            CrashReporter.shared.record(error, context: "game.dub.export", keys: ["line_count": pack.lines.count])
        }
    }
}

