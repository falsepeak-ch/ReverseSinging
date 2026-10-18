//
//  HomeVideoStudioViewModel.swift
//  DubloonMac
//
//  Home Video Dub as a one-clip editing bench: the picture, its sound, a take laid over it
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Drives the home video studio.
///
/// The take, the mix and the picture are the iPhone's `HomeVideoDubViewModel`. The Mac adds a
/// second way in, a video file from the Open panel or a drop on the viewer, next to Photos, and
/// the dashboard's lamp and timecode.
@MainActor
final class HomeVideoStudioViewModel: ObservableObject {

    let dub = HomeVideoDubViewModel()

    /// File ▸ Choose Video File… and the viewer's menu.
    @Published var isFileImporterPresented = false

    /// What the Open panel and a drop accept.
    static let videoTypes: [UTType] = [.movie, .video, .quickTimeMovie, .mpeg4Movie]

    private var cancellables = Set<AnyCancellable>()

    init() {
        dub.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Screen

    func onAppear() {
        dub.onAppear()
    }

    func onDisappear() {
        dub.onDisappear()
    }

    // MARK: - Picking

    func choosePhoto() {
        guard !dub.isBusy else { return }
        dub.isPickerPresented = true
    }

    func chooseFile() {
        guard !dub.isBusy else { return }
        isFileImporterPresented = true
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first { dub.load(fileAt: url) }
        case .failure(let error):
            dub.errorMessage = Strings.HomeVideo.loadFailed
            CrashReporter.shared.record(error, context: "home_video.file_import")
        }
    }

    /// A file dropped on the viewer. Anything but a video is turned away before it is copied.
    func handleDrop(_ urls: [URL]) -> Bool {
        guard !dub.isBusy, let url = urls.first,
              let type = UTType(filenameExtension: url.pathExtension),
              Self.videoTypes.contains(where: type.conforms(to:)) else { return false }
        dub.load(fileAt: url)
        return true
    }

    // MARK: - Dashboard

    var lamp: ProDashboard.Lamp {
        switch dub.phase {
        case .countingIn: .countIn
        case .recording: .recording
        default: dub.isPlaying ? .playing : .idle
        }
    }

    var timecode: String {
        guard let source = dub.source else { return TimeInterval(0).proTimecode }
        let fraction = dub.phase == .recording ? dub.recordingProgress : dub.playhead
        return (source.duration * fraction).proTimecode
    }

    var durationText: String? {
        dub.source.map { $0.duration.proShortTime }
    }

    var hint: String {
        switch dub.phase {
        case .recording:
            dub.isMonitoring ? Strings.HomeVideo.recordingHintHeadphones : Strings.HomeVideo.recordingHint
        case .review: Strings.HomeVideo.reviewHint
        case .empty, .importing: MacStrings.HomeVideo.emptyHint
        default: Strings.HomeVideo.readyHint
        }
    }

    var recordLabel: String {
        switch dub.phase {
        case .recording, .countingIn: Strings.HomeVideo.stop
        case .review: Strings.HomeVideo.retake
        default: Strings.HomeVideo.record
        }
    }

    var canRecord: Bool {
        dub.hasVideo && dub.phase != .mixing && dub.phase != .importing
    }

    var canPlay: Bool {
        dub.phase == .ready || dub.phase == .review
    }
}
