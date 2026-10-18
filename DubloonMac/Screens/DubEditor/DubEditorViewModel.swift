//
//  DubEditorViewModel.swift
//  DubloonMac
//
//  One pack as a project: the viewer's mode, the recording bay and the program monitor behind
//  it, and the timeline's zoom
//

import SwiftUI
import Combine
import DubAudio

/// What the viewer is showing.
enum DubViewerMode: String, CaseIterable, Identifiable {
    /// One line, with the mic ready: the recording bay.
    case line
    /// The whole scene as it was.
    case original
    /// The whole scene with the user's takes in place of the lines.
    case myDub

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line: MacStrings.Panel.line
        case .original: Strings.Dub.original
        case .myDub: Strings.Dub.myDub
        }
    }

    var playbackMode: DubPlaybackMode? {
        switch self {
        case .line: nil
        case .original: .original
        case .myDub: .myDub
        }
    }
}

/// Drives the dub editor.
///
/// The iPhone reaches the recorder and the playback screen from the pack screen, one cover at
/// a time. Here they are the same window: the line bay and the program monitor are two modes
/// of one viewer, and only one of them is live at once, which is the same rule the covers
/// kept. The bay is built once and kept, because its waveforms and camera are what the rest
/// of the editor reads; the program monitor is built each time the scene is played and torn
/// down when the viewer goes back to a line.
@MainActor
final class DubEditorViewModel: ObservableObject {

    let pack: DubPack
    /// The pack screen's model, for the export flow and the session it creates.
    let detail: DubPackDetailViewModel
    /// The recording bay. Built with the editor, live whenever the viewer is on a line.
    let record: DubRecordViewModel

    var session: DubSessionViewModel { detail.session }

    @Published private(set) var mode: DubViewerMode = .line
    /// The program monitor, while the viewer is on the whole scene.
    @Published private(set) var playback: DubPlaybackViewModel?

    /// Points per second of scene on the timeline.
    @Published var zoom: CGFloat = 24

    static let zoomRange: ClosedRange<CGFloat> = 6...160

    private var cancellables = Set<AnyCancellable>()

    init(pack: DubPack, library: DubPackLibrary) {
        self.pack = pack
        detail = DubPackDetailViewModel(pack: pack, library: library)
        record = DubRecordViewModel(session: detail.session)

        for publisher in [detail.objectWillChange, record.objectWillChange] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    // MARK: - Screen

    func onAppear() {
        detail.onAppear()
        detail.recorderDidAppear()
        // The Mac records and plays back in one window, with no cover sliding away between
        // them, so the Play My Dub tip has nothing to wait for.
        DubTips.isRecorderOpen = false
        DubTips.noteBooth(isOn: BoothCamPreference.shared.isEnabled)
        record.onAppear()
        session.jumpToFirstUnrecordedLine()
        record.lineDidChange()
        // Fit the scene to a comfortable width on arrival.
        if pack.duration > 0 { zoom = min(max(1400 / pack.duration, Self.zoomRange.lowerBound), 48) }
    }

    func onDisappear() {
        tearDownPlayback()
        record.onDisappear()
        record.cleanup()
        detail.recorderDidDismiss()
        detail.onDisappear()
    }

    // MARK: - Viewer Mode

    func setMode(_ newMode: DubViewerMode) {
        guard newMode != mode, !record.isRecording else { return }
        tearDownPlayback()
        record.stop()

        mode = newMode

        if let playbackMode = newMode.playbackMode {
            record.stopBooth()
            let model = DubPlaybackViewModel(session: session, mode: playbackMode)
            model.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
            playback = model
        } else {
            record.lineDidChange()
            Task { await record.startBoothIfEnabled() }
        }
    }

    private func tearDownPlayback() {
        guard let playback else { return }
        playback.onDisappear()
        self.playback = nil
    }

    // MARK: - Lines

    func select(_ line: DubLine) {
        guard !record.isRecording else { return }
        if playback != nil {
            // In the program monitor a click on a clip moves the head to it, the way a
            // timeline does, and a running scene keeps running from there.
            cue(line)
        } else {
            record.stop()
            session.select(line)
        }
    }

    /// Selecting a line stops the session's players; the scene is picked up again after.
    private func cue(_ line: DubLine) {
        guard let playback else { return }
        let wasPlaying = playback.player.isPlaying
        session.select(line)
        playback.player.seek(to: line.startTime)
        if wasPlaying { playback.player.resume() }
    }

    func select(lineID: DubLine.ID?) {
        guard let lineID, let line = pack.lines.first(where: { $0.id == lineID }) else { return }
        select(line)
    }

    func goToPrevious() {
        if mode == .line { record.goToPreviousLine() } else { stepScene(by: -1) }
    }

    func goToNext() {
        if mode == .line { record.goToNextLine() } else { stepScene(by: 1) }
    }

    /// In the program monitor the arrow keys jump the head from line to line.
    private func stepScene(by step: Int) {
        guard let playback else { return }
        let now = playback.player.currentTime
        let target = step > 0
            ? pack.lines.first { $0.startTime > now + 0.05 }
            : pack.lines.last { $0.startTime < now - 0.25 }
        if let target {
            cue(target)
        } else if step < 0 {
            playback.player.seek(to: 0)
        }
    }

    // MARK: - Transport

    /// Space: the take when there is a line bay, the scene when there is a program monitor.
    func togglePlay() {
        if let playback {
            playback.togglePlayPause()
        } else {
            record.toggleReferencePreview()
        }
    }

    func toggleRecord() {
        if mode != .line { setMode(.line) }
        record.toggleRecording()
    }

    func beginExport(line: DubLine? = nil) {
        guard !record.isRecording else { return }
        record.stop()
        playback?.player.pause()
        detail.beginExport(line: line)
    }

    // MARK: - Timeline

    /// Where the playhead is on the scene's clock.
    var playheadTime: TimeInterval {
        if let playback { return playback.player.currentTime }
        guard let line = session.currentLine else { return 0 }
        let progress = record.waveformProgress(for: line) ?? 0
        return line.startTime + progress * line.duration
    }

    /// The scene's full length on the timeline.
    var timelineDuration: TimeInterval {
        max(pack.duration, pack.lines.last?.endTime ?? 0, 1)
    }

    func scrub(to time: TimeInterval) {
        guard let playback, timelineDuration > 0 else { return }
        playback.scrub(to: min(max(0, time / max(playback.player.duration, 0.001)), 1))
    }

    func endScrub() {
        playback?.endScrub()
    }

    func zoomIn() { zoom = min(zoom * 1.5, Self.zoomRange.upperBound) }
    func zoomOut() { zoom = max(zoom / 1.5, Self.zoomRange.lowerBound) }

    // MARK: - Dashboard

    var lamp: ProDashboard.Lamp {
        if record.countdown != nil { return .countIn }
        if record.isRecording { return .recording }
        if let playback, playback.player.isPlaying { return .playing }
        if session.isPreviewingReference { return .playing }
        return .idle
    }

    var lineReadout: String {
        guard let line = session.currentLine else { return "" }
        return String(format: "%@ %03d/%03d", MacStrings.Panel.line.uppercased(), line.index, pack.lines.count)
    }
}
