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
    /// The paywall, once the free takes are used up. See `FreeTakes`.
    @Published var isTakePaywallPresented = false
    @Published var errorMessage: String?
    /// Opens the share sheet.
    @Published var sharedURL: URL?

    let player = AVPlayer()

    private let recorder = AudioRecorder()
    private let slate = RecordSlate()
    private var resultURL: URL?
    private var hasTake = false
    /// A new take whose mix has not landed yet, so it has not been counted as a free take.
    private var isTakeUncounted = false
    private var autoStopTask: Task<Void, Never>?
    /// Bumped by every import, so only the latest to start lands. Two can overlap: Photos takes
    /// a while to hand over a long clip, and a second tap in the picker starts another.
    private var importGeneration = 0
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
            guard let url = try await Self.loadFile(of: item) else {
                throw HomeVideoMixer.MixError.noPicture
            }
            return url
        }
        pickerItem = nil
    }

    /// As a movie first; then, when Photos offers nothing that conforms to `.movie` (it answers
    /// with `TransferableSupportError`), as whatever file it does have, which `inspect` then
    /// accepts or turns down on what AVFoundation finds in it.
    private static func loadFile(of item: PhotosPickerItem) async throws -> URL? {
        do {
            return try await item.loadTransferable(type: HomeVideoPick.self)?.url
        } catch where (error as NSError).domain.hasSuffix("TransferableSupportError") {
            // Logged rather than recorded: the lines ride along on the `home_video.load` report
            // if the fallback fails too, and say which types the item offered.
            let types = item.supportedContentTypes.map(\.identifier).joined(separator: ",")
            CrashReporter.shared.log("home_video.load no movie representation: \(types)")
            do {
                return try await item.loadTransferable(type: HomeVideoAnyFile.self)?.url
            } catch let fallback {
                let failed = fallback as NSError
                CrashReporter.shared.log("home_video.load fallback failed: \(failed.domain) \(failed.code)")
                throw error
            }
        }
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
        importGeneration += 1
        let generation = importGeneration

        Task {
            do {
                let url = try await copy()
                let measured = try await HomeVideoMixer.inspect(url)
                // A newer pick started while this one was copying. Both used to land, and the
                // second to finish swept away the first one's file, leaving a source with no
                // file behind it: the take recorded, then the mix failed with -11800.
                guard generation == importGeneration else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
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
                // The newer pick owns the screen, and its own copy may be what removed this file.
                guard generation == importGeneration else { return }
                phase = source == nil ? .empty : (resultURL == nil ? .ready : .review)
                if case HomeVideoMixer.MixError.tooShort = error {
                    // A clip under half a second: the user's pick, not the app's failure.
                    errorMessage = Strings.HomeVideo.tooShort
                    return
                }
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
        guard sourceFileIsThere(source) else { return }
        guard AccessController.shared.canStartTake else {
            isTakePaywallPresented = true
            return
        }
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
            isTakeUncounted = true
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

    /// The picked clip is a copy in Caches, which iOS may empty while the app is away. Rather
    /// than a take that can't be mixed, or a mix that fails, the studio goes back to the picker
    /// and says why.
    private func sourceFileIsThere(_ source: HomeVideoMixer.Source) -> Bool {
        guard !FileManager.default.fileExists(atPath: source.url.path) else { return true }
        CrashReporter.shared.log("home_video.source_gone")
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        self.source = nil
        resultURL = nil
        hasTake = false
        takeSamples = []
        originalSamples = []
        phase = .empty
        errorMessage = Strings.HomeVideo.sourceGone
        return false
    }

    private func remix() {
        guard let source, hasTake else { return }
        guard sourceFileIsThere(source) else { return }
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
                // Counted once the dubbed video plays, so the last free take is seen before
                // the offer. Not on a remix of the same take, when the original sound is toggled.
                if isTakeUncounted {
                    isTakeUncounted = false
                    if AccessController.shared.recordTake(.homeVideo) { isTakePaywallPresented = true }
                }
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
            Self(url: try keepCopy(of: received.file))
        }
    }

    /// The picker's file, copied into the working folder under a name of its own.
    static func keepCopy(of file: URL) throws -> URL {
        let ext = file.pathExtension.isEmpty ? "mov" : file.pathExtension
        let destination = HomeVideoMixer.workingDirectory
            .appendingPathComponent("source-\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: file, to: destination)
        return destination
    }
}

/// The fallback when an item matched the picker's video filter but offers no type that conforms
/// to `.movie`: whatever file Photos has, kept the same way.
nonisolated struct HomeVideoAnyFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .data) { received in
            Self(url: try HomeVideoPick.keepCopy(of: received.file))
        }
    }
}
