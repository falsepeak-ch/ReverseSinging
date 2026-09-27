//
//  ReverseStudioViewModel.swift
//  DubloonMac
//
//  Reverse singing as four tracks: what is on each, what is playing, and what record does next
//

import SwiftUI
import Combine
import DubAudio

/// Drives the reverse-singing studio.
///
/// The game is `ReverseGameViewModel`, the same one the iPhone plays, owned by the window so
/// a session survives a trip to a pack. This lays its four recordings out as tracks, knows
/// which one is playing, and decides what the one record key means at each step. An archived
/// session is the same studio with the record key taken away.
@MainActor
final class ReverseStudioViewModel: ObservableObject {

    /// One track of the session.
    struct Lane: Identifiable {
        let type: Recording.RecordingType
        let recording: Recording?

        var id: String { type.rawValue }

        var title: String {
            switch type {
            case .original, .imported: Strings.RecordingType.original
            case .reversed: Strings.RecordingType.reversed
            case .attempt: Strings.RecordingType.attempt
            case .reversedAttempt: Strings.RecordingType.reversedAttempt
            }
        }

        var icon: String {
            switch type {
            case .original, .imported: "music.mic"
            case .reversed: "arrow.uturn.backward"
            case .attempt: "person.wave.2"
            case .reversedAttempt: "arrow.uturn.forward"
            }
        }

        var tint: Color {
            switch type {
            case .original, .imported: .rsHighlight
            case .reversed: .proAudioClip
            case .attempt: .rsRecord
            case .reversedAttempt: .rsCaution
            }
        }
    }

    /// What the record key does now.
    enum RecordStep {
        case recordOriginal
        case recordAttempt
        case anotherTake
        case stopOriginal
        case stopAttempt
        /// Busy reversing, or looking at the archive.
        case unavailable
    }

    let game: ReverseGameViewModel
    /// Set when this studio shows a session from the archive rather than the one in progress.
    let archived: AudioSession?

    @Published private(set) var playingRecordingID: UUID?
    @Published private(set) var waveforms: [UUID: [Float]] = [:]

    private var cancellables = Set<AnyCancellable>()

    init(game: ReverseGameViewModel, archived: AudioSession?) {
        self.game = game
        self.archived = archived

        game.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        game.$appState
            .map(\.recordingState)
            .removeDuplicates()
            .sink { [weak self] state in
                if state != .playing { self?.playingRecordingID = nil }
            }
            .store(in: &cancellables)
    }

    // MARK: - Session

    var session: AudioSession? { archived ?? game.appState.currentSession }

    var isArchived: Bool { archived != nil }

    var lanes: [Lane] {
        let session = session
        return [
            Lane(type: .original, recording: session?.originalRecording),
            Lane(type: .reversed, recording: session?.reversedRecording),
            Lane(type: .attempt, recording: session?.attemptRecording),
            Lane(type: .reversedAttempt, recording: session?.reversedAttempt)
        ]
    }

    var hasRecordings: Bool { !(session?.recordings.isEmpty ?? true) }

    var isRecording: Bool { game.appState.recordingState == .recording }

    var score: Double? { isArchived ? nil : game.appState.similarityScore }

    // MARK: - Screen

    func onAppear() {
        game.checkPermissionStatus()
        AnalyticsManager.shared.trackScreenViewed(screenName: isArchived ? "MacSessionArchive" : "MacReverseStudio")
    }

    func onDisappear() {
        game.stopPlayback()
    }

    /// Reads the shape of every recording on the tracks that has not been read yet.
    func loadWaveforms() async {
        for lane in lanes {
            guard let recording = lane.recording, waveforms[recording.id] == nil else { continue }
            let samples = await WaveformSampler.shared.samples(from: recording.url, buckets: 220)
            waveforms[recording.id] = samples
        }
    }

    /// A key that changes whenever a track gets a new recording, to reload the shapes.
    var waveformKey: [UUID] { lanes.compactMap { $0.recording?.id } }

    // MARK: - Playback

    func isPlaying(_ lane: Lane) -> Bool {
        lane.recording.map { $0.id == playingRecordingID } ?? false
    }

    func progress(of lane: Lane) -> Double? {
        guard isPlaying(lane), game.playbackDuration > 0 else { return nil }
        return min(1, game.playbackProgress / game.playbackDuration)
    }

    func toggle(_ lane: Lane) {
        guard let recording = lane.recording, !isRecording else { return }
        if isPlaying(lane) {
            game.stopPlayback()
            playingRecordingID = nil
        } else {
            game.playRecording(recording)
            playingRecordingID = recording.id
        }
    }

    /// Space: the most useful thing to hear next, or stop.
    func togglePlay() {
        if playingRecordingID != nil {
            game.stopPlayback()
            playingRecordingID = nil
            return
        }
        let preferred: [Recording.RecordingType] = [.reversed, .reversedAttempt, .original, .attempt]
        for type in preferred {
            if let lane = lanes.first(where: { $0.type == type && $0.recording != nil }) {
                toggle(lane)
                return
            }
        }
    }

    // MARK: - Recording

    var recordStep: RecordStep {
        guard !isArchived else { return .unavailable }
        let session = game.appState.currentSession
        switch game.appState.recordingState {
        case .recording:
            return session?.reversedRecording != nil ? .stopAttempt : .stopOriginal
        case .reversing:
            return .unavailable
        default:
            if session?.attemptRecording != nil { return .anotherTake }
            if session?.reversedRecording != nil { return .recordAttempt }
            if session?.originalRecording != nil { return .unavailable }
            return .recordOriginal
        }
    }

    var recordTitle: String {
        switch recordStep {
        case .recordOriginal: Strings.Main.recordAudio
        case .recordAttempt: Strings.Main.recordAttempt
        case .anotherTake: Strings.Main.reRecord
        case .stopOriginal, .stopAttempt: Strings.Main.stopRecording
        case .unavailable: Strings.Main.recordAudio
        }
    }

    func toggleRecord() {
        game.stopPlayback()
        switch recordStep {
        case .recordOriginal, .recordAttempt:
            game.startRecording()
        case .anotherTake:
            game.reRecordAttempt()
            game.startRecording()
        case .stopOriginal:
            game.stopRecording()
        case .stopAttempt:
            game.stopRecording(type: .attempt)
        case .unavailable:
            break
        }
    }

    // MARK: - Dashboard

    var lamp: ProDashboard.Lamp {
        if game.countdown != nil { return .countIn }
        switch game.appState.recordingState {
        case .recording: return .recording
        case .playing: return .playing
        default: return .idle
        }
    }

    var timecode: String {
        switch game.appState.recordingState {
        case .recording: game.recordingDuration.proTimecode
        case .playing: game.playbackProgress.proTimecode
        default: TimeInterval(0).proTimecode
        }
    }

    /// The next thing to do, in the words the iPhone's hint bar uses.
    var hint: String {
        guard !isArchived else { return session?.formattedDate ?? "" }
        guard let session = game.appState.currentSession else { return Strings.Main.Tip.tapRecordToBegin }

        switch game.appState.recordingState {
        case .recording:
            return session.reversedRecording != nil
                ? Strings.Main.Tip.recordSingingAttempt
                : Strings.Main.Tip.recordSongToReverse
        case .playing:
            return Strings.Main.Tip.tapPlayToSwitch
        default:
            if session.attemptRecording != nil { return Strings.Main.Tip.reRecordOrNewSession }
            if session.reversedRecording != nil { return Strings.Main.Tip.listenAndRecord }
            if session.originalRecording != nil { return Strings.Main.Tip.processingAudio }
            return Strings.Main.Tip.tapRecordAudio
        }
    }

    /// What an empty track says it is waiting for.
    func placeholder(for lane: Lane) -> String {
        switch lane.type {
        case .original, .imported: Strings.Main.Subtitle.noRecording
        case .reversed: Strings.Main.Subtitle.noReversed
        case .attempt: Strings.Main.Subtitle.recordAttempt
        case .reversedAttempt: Strings.Main.Subtitle.noReversed
        }
    }

    // MARK: - Session

    func newSession() {
        game.startNewSession()
    }

    func saveSession() {
        game.saveSession()
    }
}
