//
//  GameDubRoundViewModel.swift
//  DubloonGame
//
//  A scene, played line by line: the session and the recorder, and what the stage shows.
//

import SwiftUI
import Combine
import DubScoring

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
}

