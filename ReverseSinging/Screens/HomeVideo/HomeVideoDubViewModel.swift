//
//  HomeVideoDubViewModel.swift
//  ReverseSinging
//
//  Home Video Dub: pick a video, talk over it, share it
//

import AVFoundation
import Combine
import CoreTransferable
import DubAudio
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class HomeVideoDubViewModel: ObservableObject {

    enum Phase: Equatable {
        /// Nothing picked yet: the studio, with the picker where the picture goes.
        case empty
        /// The picked video is being copied out of the library.
        case importing
        /// A video is loaded and waiting for a take.
        case ready
        /// The 3-2-1 slate.
        case countingIn
        /// The mic is open and the video is rolling.
        case recording
        /// The voice is being laid onto the video.
        case mixing
        /// The finished video is on screen.
        case review
    }

    @Published private(set) var phase: Phase = .empty
    @Published private(set) var source: HomeVideoMixer.Source?
    @Published private(set) var countdown: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var playhead: Double = 0
    /// The clip's own sound, drawn under the picture so a voice can be timed against it.
    @Published private(set) var originalSamples: [Float] = []
    /// The last take, on the same time axis as `originalSamples`.
    @Published private(set) var takeSamples: [Float] = []
    /// True when the clip is heard in headphones during the take rather than muted.
    @Published private(set) var isMonitoring = false

    /// Whether the clip's own sound stays, quietly, under the voice. Remembered between visits,
    /// and on until someone turns it off: a home video's own sound is usually half the joke.
    @Published var keepsOriginalSound: Bool {
        didSet {
            UserDefaults.standard.set(keepsOriginalSound, forKey: Self.keepOriginalKey)
            guard oldValue != keepsOriginalSound, phase == .review else { return }
            remix()
        }
    }

    @Published var pickerItem: PhotosPickerItem? {
        didSet { if let pickerItem { load(pickerItem) } }
    }

    /// The header's change-video button, once a video is loaded.
    @Published var isPickerPresented = false
    @Published var showPermissionAlert = false
    @Published var errorMessage: String?
    /// Opens the share sheet.
    @Published var sharedURL: URL?

    let player = AVPlayer()

    private let recorder = AudioRecorder()
    private let slate = RecordSlate()
    private var resultURL: URL?
    private var hasTake = false
    private var autoStopTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    private static let keepOriginalKey = "homeVideo.keepOriginalSound"
    /// What the file is called where it lands, AirDrop and Files included.
    private static let exportName = "Dubloon Home Video.mp4"

    /// The same runway the other recorders use between choosing the start and sample zero, so
    /// the picture can be told the exact instant too.
    private static let recordingStartLeadIn: TimeInterval = 0.15

    /// Bars across the waveform. Enough to see where a laugh or a bark lands in a minute of clip.
    private static let waveformBuckets = 120

    init() {
        keepsOriginalSound = UserDefaults.standard.object(forKey: Self.keepOriginalKey) as? Bool ?? true

        recorder.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        player.actionAtItemEnd = .pause
        // Required by `setRate(_:time:atHostTime:)`, which otherwise raises.
        player.automaticallyWaitsToMinimizeStalling = false
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.timeDidChange(time) }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let item = note.object as? AVPlayerItem
            MainActor.assumeIsolated { self?.itemDidEnd(item) }
        }
    }

    // MARK: - Derived

    var level: Float { recorder.recordingLevel }

    /// 0...1 of the video recorded so far, for the ring on the record button.
    var recordingProgress: Double {
        guard let source, source.duration > 0 else { return 0 }
        return min(1, recorder.recordingDuration / source.duration)
    }

    var isBusy: Bool {
        phase == .importing || phase == .countingIn || phase == .recording || phase == .mixing
    }

    var hasVideo: Bool { source != nil }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "HomeVideoDub")
    }

    func onDisappear() {
        slate.cancel()
        cancelAutoStop()
        if recorder.isRecording { recorder.cancelRecording() }
        player.pause()
        isPlaying = false
    }

    // MARK: - Picking

    private func load(_ item: PhotosPickerItem) {
        importVideo {
            guard let picked = try await item.loadTransferable(type: HomeVideoPick.self) else {
                throw HomeVideoMixer.MixError.noPicture
            }
            return picked.url
        }
        pickerItem = nil
    }

    /// A video file handed over directly rather than through Photos: the Mac's Open panel, or a
    /// file dropped on the picture. Copied into the working folder like a picked one, so the
    /// original is never touched and never has to stay reachable.
    func load(fileAt url: URL) {
        importVideo {
            let destination = HomeVideoMixer.workingDirectory
                .appendingPathComponent("source-\(UUID().uuidString).\(url.pathExtension.isEmpty ? "mov" : url.pathExtension)")
            try await Task.detached {
                let isScoped = url.startAccessingSecurityScopedResource()
                defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
                try FileManager.default.copyItem(at: url, to: destination)
            }.value
            return destination
        }
    }

    private func importVideo(_ copy: @escaping @MainActor () async throws -> URL) {
        guard !isBusy || phase == .importing else { return }
        player.pause()
        isPlaying = false
        phase = .importing

        Task {
            do {
                let url = try await copy()
                let measured = try await HomeVideoMixer.inspect(url)
                HomeVideoMixer.removeWorkingFiles(except: url)
                source = measured
                resultURL = nil
                hasTake = false
                takeSamples = []
                originalSamples = []
                show(measured.url, muted: false)
                phase = .ready
                AnalyticsManager.shared.trackHomeVideoPicked(
                    duration: measured.duration, trimmed: measured.wasTrimmed, hasSound: measured.hasSound
                )
                await loadOriginalWaveform(of: measured)
            } catch {
                phase = source == nil ? .empty : (resultURL == nil ? .ready : .review)
                errorMessage = Strings.HomeVideo.loadFailed
                CrashReporter.shared.record(error, context: "home_video.load")
            }
        }
    }

    // MARK: - Waveforms

    /// A silent clip, or one whose sound can't be decoded, just draws an empty rail.
    private func loadOriginalWaveform(of source: HomeVideoMixer.Source) async {
        guard let url = try? await HomeVideoMixer.extractOriginalSound(of: source) else { return }
        await WaveformSampler.shared.invalidate(url)
        let samples = await WaveformSampler.shared.samples(from: url, buckets: Self.waveformBuckets)
        guard self.source == source else { return }
        originalSamples = samples
    }

    /// The take at the clip's seconds-per-bar, so a take stopped early draws short.
    private func loadTakeWaveform() async {
        let url = HomeVideoMixer.voiceURL
        guard let source, source.duration > 0,
              let duration = await AudioFileManager.shared.getAudioDurationAsync(from: url) else { return }
        await WaveformSampler.shared.invalidate(url)
        let buckets = max(1, Int((Double(Self.waveformBuckets) * duration / source.duration).rounded()))
        takeSamples = await WaveformSampler.shared.samples(from: url, buckets: min(buckets, Self.waveformBuckets))
    }

    // MARK: - Watching

    /// Tapping the picture: play or pause what's loaded, from the top once it has ended.
    func togglePlayback() {
        guard phase == .ready || phase == .review else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if let item = player.currentItem, item.currentTime() >= item.duration {
                player.seek(to: .zero)
            }
            player.play()
            isPlaying = true
        }
    }

    private func show(_ url: URL, muted: Bool) {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.isMuted = muted
        playhead = 0
    }

    private func timeDidChange(_ time: CMTime) {
        guard let source, source.duration > 0 else { return }
        playhead = min(1, max(0, time.seconds / source.duration))
        // A trimmed clip keeps playing past the part that is used; stop it at the cap.
        if phase == .ready, time.seconds >= source.duration, isPlaying {
            player.pause()
            isPlaying = false
        }
    }

    private func itemDidEnd(_ item: AVPlayerItem?) {
        guard item === player.currentItem else { return }
        isPlaying = false
    }

    // MARK: - Recording

    /// The big button: start the count, or stop the take early.
    func toggleRecording() {
        switch phase {
        case .countingIn:
            slate.cancel()
            countdown = nil
            phase = hasTake ? .review : .ready
        case .recording:
            stopRecording()
        case .ready, .review:
            startRecording()
        case .empty, .importing, .mixing:
            break
        }
    }

    private func startRecording() {
        guard let source else { return }
        player.pause()
        isPlaying = false

        recorder.requestPermission { [weak self] answer in
            guard let self else { return }
            guard answer == .granted else {
                // A no given to the prompt just now is an answer, and nothing follows it.
                self.showPermissionAlert = answer == .refusedEarlier
                AnalyticsManager.shared.trackPermissionDenied()
                return
            }
            guard self.recorder.canStartRecording() else { return }

            // The clip itself, parked on its first frame while the slate runs. Silent through
            // the speaker, where it would land in the take; heard in headphones, where it can't,
            // so a sound can be answered as it happens.
            HeadphoneMonitor.shared.refresh()
            self.isMonitoring = source.hasSound && HeadphoneMonitor.shared.shouldPlayOriginalWhileRecording
            self.show(source.url, muted: !self.isMonitoring)
            self.phase = .countingIn
            self.slate.run(
                onBeat: { [weak self] beat in self?.countdown = beat },
                thenRecord: { [weak self] in self?.beginRecording() }
            )
        }
    }

    private func beginRecording() {
        guard let source, AppActivity.canOpenMicrophone, recorder.canStartRecording() else {
            phase = hasTake ? .review : .ready
            return
        }

        do {
            SoundManager.shared.setMicrophoneOpen(true)
            _ = try recorder.startRecording(
                maxDuration: source.duration,
                startDelay: Self.recordingStartLeadIn,
                onScheduled: { [weak self] hostTime in
                    // The picture rolls on the microphone's deadline, so the take's sample zero
                    // is the video's first frame.
                    self?.player.setRate(1, time: .zero, atHostTime: CMClockMakeHostTimeFromSystemUnits(hostTime))
                    self?.isPlaying = true
                }
            )
            phase = .recording
            HapticManager.shared.heavy()
            scheduleAutoStop(after: source.duration + Self.recordingStartLeadIn)
        } catch {
            SoundManager.shared.setMicrophoneOpen(false)
            phase = hasTake ? .review : .ready
            errorMessage = error.localizedDescription
            SoundManager.shared.play(.errorThunk)
            CrashReporter.shared.record(error, context: "home_video.record_start")
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
        isMonitoring = false
        SoundManager.shared.setMicrophoneOpen(false)
        player.pause()
        isPlaying = false

        guard let temporaryURL = recorder.stopRecording() else {
            phase = hasTake ? .review : .ready
            errorMessage = Strings.Error.failedToStopRecording
            return
        }

        SoundManager.shared.play(.tapeStop)
        HapticManager.shared.heavy()

        do {
            try? FileManager.default.removeItem(at: HomeVideoMixer.voiceURL)
            try FileManager.default.moveItem(at: temporaryURL, to: HomeVideoMixer.voiceURL)
            hasTake = true
            Task { await loadTakeWaveform() }
        } catch {
            phase = .ready
            errorMessage = Strings.HomeVideo.mixFailed
            CrashReporter.shared.record(error, context: "home_video.save_take")
            return
        }
        remix()
    }

    // MARK: - Mixing

    private func remix() {
        guard let source, hasTake else { return }
        player.pause()
        isPlaying = false
        phase = .mixing
        let keepOriginal = keepsOriginalSound
        let output = AudioFileManager.shared.dubExportsDirectory()
            .appendingPathComponent(Self.exportName)

        Task {
            let work = LongRunningWork(name: "home_video.mix")
            defer { work.end() }
            do {
                let url = try await HomeVideoMixer.render(
                    source: source,
                    voice: HomeVideoMixer.voiceURL,
                    keepOriginal: keepOriginal,
                    to: output
                )
                resultURL = url
                show(url, muted: false)
                phase = .review
                player.play()
                isPlaying = true
                AnalyticsManager.shared.trackHomeVideoMixed(duration: source.duration, keptOriginal: keepOriginal)
            } catch {
                phase = .ready
                show(source.url, muted: false)
                errorMessage = Strings.HomeVideo.mixFailed
                CrashReporter.shared.record(error, context: "home_video.mix")
            }
        }
    }

    // MARK: - Sharing

    func share() {
        guard phase == .review, let resultURL else { return }
        player.pause()
        isPlaying = false
        sharedURL = resultURL
        AnalyticsManager.shared.trackHomeVideoShared()
    }
}

/// A video handed over by the Photos picker, copied somewhere the app can keep reading it.
///
/// The picker's own copy lives only as long as the import callback, and going through it needs
/// no access to the photo library at all.
nonisolated struct HomeVideoPick: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { pick in
            SentTransferredFile(pick.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = HomeVideoMixer.workingDirectory
                .appendingPathComponent("source-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}
