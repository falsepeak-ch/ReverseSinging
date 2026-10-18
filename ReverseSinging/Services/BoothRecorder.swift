//
//  BoothRecorder.swift
//  ReverseSinging
//
//  The front-camera capture that rolls beside a dub take
//

import AVFoundation
import Combine
import CoreMedia
import DubCompositing

// MARK: - Booth Recorder

/// Films the performer while they dub, and writes one silent clip per take.
///
/// **Video only, deliberately.** The microphone belongs to `AudioRecorder` for the whole of a
/// take. A capture session that also claimed it would either fight for the route or
/// reconfigure the audio session out from under the recorder, and `AudioRecorder` picks a
/// future host-time boundary on the assumption that nothing else is moving underneath it.
/// So the booth clip carries no audio at all: the voice that goes with it is the take itself,
/// which is also what keeps the two in sync for free.
///
/// **Sync comes from the anchor, not from when this happens to be called.** `startTake` takes
/// the same `mach_absolute_time()` deadline the recorder scheduled sample zero on, and the
/// writer's session starts at exactly that instant. Frames that arrive before it are dropped
/// rather than written, so a camera that took a moment longer to deliver its first buffer
/// does not bake a leading offset into every clip. That is the same mistake the scene picture
/// used to make, and it was still visible on playback. The frame closest to that instant
/// stands in for it, so the clip has a picture from its first moment; see `DubBoothTakeClock`.
///
/// **A take only replaces the previous clip once it is kept.** Footage is written to a scratch
/// file and moved over the line's clip by `finishTake`, the moment the voice take is kept too.
/// A take that is cancelled, interrupted or fails leaves the last good clip where it was.
final class BoothRecorder: ObservableObject {

    // MARK: State

    enum Availability: Equatable {
        /// Not asked yet.
        case unknown
        /// Camera present and permitted.
        case ready
        /// The user said no, in the system prompt or in Settings afterwards.
        case denied
        /// No usable front camera, or the session could not be configured.
        case unavailable
    }

    @Published private(set) var availability: Availability = .unknown
    /// Whether the preview is live. The monitor draws nothing until this is true, so it never
    /// shows a black rectangle where a face is about to be. False while the system has the
    /// camera (a call, another app using it, the device too hot), and true again after.
    @Published private(set) var isPreviewing = false
    /// Between asking for the camera and it running. A take started now is still filmed: it
    /// waits on the capture queue behind the start-up, which is what lets someone switch the
    /// camera on and press record straight away.
    private var isStarting = false
    /// Whether a take is being written to disk right now.
    @Published private(set) var isWriting = false

    /// Whether there is any point drawing the monitor: either the camera is live, or it is
    /// still starting up. False on a device that has told us it cannot film, so the picture
    /// is never given up for a rectangle that will stay empty.
    var isUsable: Bool {
        switch availability {
        case .unknown, .ready: return true
        case .denied, .unavailable: return false
        }
    }

    /// Handed to `BoothPreviewView`. Owned by the capture core so the session outlives any
    /// view redraw.
    var session: AVCaptureSession { capture.session }

    private let capture = BoothCapture()

    // MARK: - Permission

    /// What the system already knows about the camera, without prompting for it.
    ///
    /// Deliberately not an `AVAuthorizationStatus`: the screens that ask this question only
    /// need to know which of three things to do, and handing them an AVFoundation enum makes
    /// every one of them import a capture framework to read one case.
    enum CameraPermission {
        /// Granted. Filming can start.
        case granted
        /// Never asked. The prompt is still available, so the app should make its case first.
        case unasked
        /// Refused, here or in the Settings app. Only the user can undo this, and not from
        /// inside the app.
        case refused
    }

    nonisolated static var cameraPermission: CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return .unasked
        default: return .refused
        }
    }

    /// Prompts if the user has not been asked. Returns whether filming is allowed.
    ///
    /// The app has already made its own case by the time this runs, see `BoothCamPrimerModal`.
    nonisolated static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Lifecycle

    init() {
        capture.onInterruption = { [weak self] isInterrupted in
            Task { @MainActor in self?.interruptionDidChange(isInterrupted) }
        }
    }

    /// Brings the preview up, asking for camera access if it has not been asked for yet.
    ///
    /// Safe to call on every appearance: configuration happens once, and starting a session
    /// that is already running is a no-op. Called as soon as the booth opens with the camera
    /// on, so the session is warm long before the first take's countdown ends.
    func start() async {
        switch Self.cameraPermission {
        case .granted:
            break
        case .unasked:
            guard await Self.requestAccess() else {
                availability = .denied
                return
            }
        case .refused:
            availability = .denied
            return
        }

        isStarting = true
        let isRunning = await capture.configureAndRun()
        isStarting = false

        availability = isRunning ? .ready : .unavailable
        isPreviewing = isRunning
    }

    /// Tears the preview down. Called when the record screen goes away, so the camera light
    /// is never on while the user is somewhere else in the app.
    func stop() {
        isPreviewing = false
        isWriting = false
        isStarting = false
        capture.stop()
    }

    private func interruptionDidChange(_ isInterrupted: Bool) {
        guard availability == .ready else { return }
        isPreviewing = !isInterrupted
    }

    // MARK: - Takes

    /// Begins writing a clip that starts at `anchorHostTime` and runs for `duration`.
    ///
    /// - Parameters:
    ///   - anchorHostTime: the `mach_absolute_time()` deadline the microphone opens on.
    ///   - duration: the line's length. Zero means "until told to stop".
    ///   - destination: where the clip lands once the take is kept. Left alone until then.
    func startTake(anchorHostTime: UInt64, duration: TimeInterval, to destination: URL) {
        guard isUsable, isPreviewing || isStarting else { return }

        isWriting = true
        let anchor = CMClockMakeHostTimeFromSystemUnits(anchorHostTime)

        capture.startTake(destination: destination, anchor: anchor, duration: duration) { [weak self] in
            Task { @MainActor in self?.isWriting = false }
        }
    }

    /// Closes the current clip, moves it over the line's previous one, and returns where it
    /// landed, or nil if nothing was written.
    ///
    /// A take that never received a frame produces no file rather than an empty one, so
    /// "is there booth footage for this line" stays a question about the filesystem.
    @discardableResult
    func finishTake() async -> URL? {
        isWriting = false
        return await capture.finishTake()
    }

    /// Drops the current clip without keeping it. For a take the user abandoned. The line's
    /// previous clip, if it has one, is untouched.
    func cancelTake() {
        isWriting = false
        capture.cancelTake()
    }
}

// MARK: - Capture

/// The capture pipeline itself: the session, its output, and the take being written.
///
/// **Everything here lives on `queue`.** The sample-buffer delegate is called on it, and every
/// command from `BoothRecorder` hops onto it before touching anything. A session reconfigured
/// from the main thread while frames are being delivered on another is the classic way to get
/// an intermittent stall. That confinement is what `@unchecked Sendable` stands for: the
/// compiler cannot see a dispatch queue, and an actor running on this queue cannot be entered
/// synchronously from the delegate on iOS 17.
///
/// The one exception is `session`, which `BoothPreviewView` attaches to its preview layer from
/// the main thread. That is how AVFoundation expects a preview to be wired.
nonisolated private final class BoothCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    let session = AVCaptureSession()

    /// Told when the system takes the camera away and when it gives it back. Any thread.
    var onInterruption: (@Sendable (Bool) -> Void)?

    private let queue = DispatchQueue(label: "ch.falsepeak.dubloon.booth.capture")
    private let output = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private var camera: AVCaptureDevice?
    private var observers: [NSObjectProtocol] = []
    private var pressureObservation: NSKeyValueObservation?

    #if os(iOS)
    /// Which way up the performer is, from the device's own sense of gravity. Read at the
    /// start of each take, never during one.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    #endif

    /// The take being written, or the one waiting for its first frame, or one that reached
    /// its end on the capture clock and is waiting to be collected.
    private var take: Take?

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Configures the session if it has not been, and starts it.
    ///
    /// - Returns: whether it is running.
    func configureAndRun() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.configureIfNeeded() else {
                    continuation.resume(returning: false)
                    return
                }
                if !self.session.isRunning { self.session.startRunning() }
                continuation.resume(returning: self.session.isRunning)
            }
        }
    }

    func stop() {
        queue.async {
            self.take?.abandon()
            self.take = nil
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// - Parameter onEnd: called on `queue` when the take reaches `duration` by itself.
    func startTake(
        destination: URL,
        anchor: CMTime,
        duration: TimeInterval,
        onEnd: @escaping @Sendable () -> Void
    ) {
        queue.async {
            self.take?.abandon()
            self.lockOrientationForTake()

            // The anchor is a host-clock time; frames are stamped on the session's clock.
            // They are the same clock on every device seen so far, but converting costs
            // nothing and is what keeps the booth honest on one where they are not.
            let clock = self.session.synchronizationClock ?? CMClockGetHostTimeClock()
            let sessionAnchor = CMSyncConvertTime(anchor, from: CMClockGetHostTimeClock(), to: clock)

            self.take = Take(
                destination: destination,
                anchor: sessionAnchor.isValid ? sessionAnchor : anchor,
                duration: duration,
                queue: self.queue,
                onEnd: onEnd
            )
        }
    }

    func finishTake() async -> URL? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let take = self.take else {
                    continuation.resume(returning: nil)
                    return
                }
                self.take = nil
                take.commit { continuation.resume(returning: $0) }
            }
        }
    }

    func cancelTake() {
        queue.async {
            self.take?.abandon()
            self.take = nil
        }
    }

    // MARK: Configuration

    /// The camera facing the performer: the front camera on an iPhone, the one in the lid
    /// (or whichever the system picks by default) on a Mac.
    private static func boothCamera() -> AVCaptureDevice? {
        #if os(iOS)
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        #else
        AVCaptureDevice.default(for: .video)
        #endif
    }

    /// Wires the front camera in, once. Runs on `queue`.
    ///
    /// - Returns: whether there is a usable front camera to preview at all. False on a
    ///   device without one, and on the Simulator, which has no capture device to offer.
    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }

        // The one line that keeps this out of `AudioRecorder`'s way. Left at its default,
        // AVFoundation reconfigures the shared audio session when capture starts.
        #if os(iOS)
        session.automaticallyConfiguresApplicationAudioSession = false
        #endif

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 720p, not 1080p. The booth is a corner inset or half a frame, never the whole of
        // one, and this roughly halves what a session costs on disk.
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }

        guard let camera = Self.boothCamera(), let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            return false
        }
        session.addInput(input)
        self.camera = camera

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            // Upright for a phone held in portrait until the first take says otherwise. A Mac
            // camera is already the right way up, and its clip stays landscape.
            #if os(iOS)
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: nil)
            #endif
            // The preview is mirrored to taste (see `BoothCamPreference.mirrorsPreview`); the
            // recording never is, so a shirt with writing on it reads correctly to whoever
            // ends up watching the clip.
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        observeSession(camera: camera)

        isConfigured = true
        return true
    }

    /// Turns the written picture upright for however the device is held right now.
    ///
    /// Read at the start of a take and then left alone, on purpose. An iPhone Duo opened into
    /// landscape, laid into tabletop, or a phone simply turned, all change what upright means;
    /// changing it *mid-take* would change the size of the frames being handed to a writer
    /// that was built for the first one, and the clip would fail. So a take keeps the
    /// orientation it started in, and the next one picks up the new one.
    private func lockOrientationForTake() {
        #if os(iOS)
        guard let connection = output.connection(with: .video), let rotationCoordinator else { return }
        let angle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
        if connection.videoRotationAngle != angle, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        #endif
    }

    // MARK: Interruptions

    /// Keeps the preview honest and the session alive when the system steps in.
    ///
    /// - A call, another app taking the camera, or Split View: the session is interrupted and
    ///   resumes by itself when the interruption ends. The monitor is told, so it does not
    ///   sit on a frozen face. A take in progress simply has no frames for that stretch; the
    ///   ones on either side keep their own timestamps, so what is there stays in sync.
    /// - Media services reset, or any other runtime error: the session stops and does *not*
    ///   come back by itself, so it is restarted here.
    /// - The device getting hot: the frame rate is lowered before the system has to stop the
    ///   camera outright, which it does at `shutdown` by interrupting the session.
    private func observeSession(camera: AVCaptureDevice) {
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                // Give media services a moment to come back before asking for the camera.
                self.queue.asyncAfter(deadline: .now() + 0.5) {
                    if !self.session.isRunning { self.session.startRunning() }
                    self.onInterruption?(!self.session.isRunning)
                }
            }
        })

        #if os(iOS)
        observers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            self?.onInterruption?(true)
        })

        observers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            self?.onInterruption?(false)
        })

        pressureObservation = camera.observe(\.systemPressureState, options: [.initial, .new]) { [weak self] device, _ in
            let level = device.systemPressureState.level
            self?.queue.async { Self.throttle(device, for: level) }
        }
        #endif
    }

    #if os(iOS)
    /// 30 fps when the device is comfortable, 24 when it is warm, 15 when it is hot.
    private static func throttle(_ device: AVCaptureDevice, for level: AVCaptureDevice.SystemPressureState.Level) {
        let rate: Int32?
        switch level {
        case .serious: rate = 24
        case .critical: rate = 15
        default: rate = nil
        }

        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        if let rate {
            let duration = CMTime(value: 1, timescale: rate)
            let supported = device.activeFormat.videoSupportedFrameRateRanges.contains {
                $0.minFrameDuration <= duration && duration <= $0.maxFrameDuration
            }
            guard supported else { return }
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
        } else {
            // Back to the format's own default.
            device.activeVideoMinFrameDuration = .invalid
            device.activeVideoMaxFrameDuration = .invalid
        }
    }
    #endif

    // MARK: Sample Buffer Delegate

    /// Arrives on `queue`, which is where every piece of writer state lives.
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let take, !take.hasEnded else { return }

        if take.append(sampleBuffer) == .reachedEnd {
            // The line is over. Close on the capture clock rather than waiting for the UI to
            // notice, so every clip is exactly the stretch of film it belongs to. The take
            // stays here until `finishTake` collects it, which is what makes this race
            // harmless: whichever of the two gets there first, the clip is the same.
            take.end()
            take.onEnd()
        }
    }
}

// MARK: - Take

/// One clip being written. Created and used only on `BoothCapture`'s queue, which is also
/// where the writer's completions are brought back to.
///
/// Written to a scratch file, never straight over the line's clip: the clip on disk belongs to
/// the voice take on disk, and only `commit` (the voice take being kept) replaces it.
nonisolated private final class Take {

    enum AppendResult { case ignored, written, reachedEnd }

    let onEnd: @Sendable () -> Void

    private let destination: URL
    private let scratch: URL
    private let anchor: CMTime
    private let queue: DispatchQueue
    private var clock: DubBoothTakeClock

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var hasStartedSession = false
    private var wroteAnything = false
    /// The last frame from just before the anchor, kept in case it is the closest the camera
    /// gets to the take's first instant.
    private var stash: CMSampleBuffer?

    private enum Outcome { case writing, finishing, finished(URL?) }
    private var outcome: Outcome = .writing
    private var isAbandoned = false
    private var waiters: [(URL?) -> Void] = []

    /// Whether the take has stopped accepting frames.
    var hasEnded: Bool {
        if case .writing = outcome { return false }
        return true
    }

    init(destination: URL, anchor: CMTime, duration: TimeInterval, queue: DispatchQueue, onEnd: @escaping @Sendable () -> Void) {
        self.destination = destination
        self.anchor = anchor
        self.queue = queue
        self.onEnd = onEnd
        clock = DubBoothTakeClock(anchor: anchor.seconds, duration: duration)
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("booth-take-\(UUID().uuidString).mov")
    }

    func append(_ sampleBuffer: CMSampleBuffer) -> AppendResult {
        guard case .writing = outcome else { return .ignored }

        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        switch clock.step(forFrameAt: presentation.seconds) {
        case .drop:
            return .ignored
        case .stash:
            stash = sampleBuffer
            return .ignored
        case .end:
            return .reachedEnd
        case .write(let at, let stashFirst):
            // The writer is built from the first frame that counts, so its dimensions are the
            // ones the connection actually delivered rather than the ones the preset promised.
            if writer == nil {
                guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
                      makeWriter(matching: format) else { return .ignored }
            }
            guard let writer, writer.status == .writing else { return .ignored }

            if !hasStartedSession {
                writer.startSession(atSourceTime: anchor)
                hasStartedSession = true
            }

            if stashFirst, let stash, let standIn = retimed(stash, to: anchor) {
                _ = write(standIn)
            }
            stash = nil

            let frame = at == clock.anchor && presentation != anchor
                ? retimed(sampleBuffer, to: anchor) ?? sampleBuffer
                : sampleBuffer
            return write(frame) ? .written : .ignored
        }
    }

    private func write(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let input, input.isReadyForMoreMediaData, input.append(sampleBuffer) else { return false }
        wroteAnything = true
        return true
    }

    private func retimed(_ sampleBuffer: CMSampleBuffer, to time: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )
        var copy: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &copy
        )
        return copy
    }

    /// Stops taking frames and closes the scratch file. Safe to call more than once.
    func end() {
        finish { _ in }
    }

    /// Closes the scratch file, then reports it (or nil, if nothing usable was written).
    private func finish(_ completion: @escaping (URL?) -> Void) {
        switch outcome {
        case .finished(let url):
            completion(url)
            return
        case .finishing:
            waiters.append(completion)
            return
        case .writing:
            break
        }

        waiters.append(completion)
        outcome = .finishing
        stash = nil

        guard let writer, let input, writer.status == .writing, wroteAnything else {
            discardWriter()
            settle(nil)
            return
        }

        input.markAsFinished()
        let scratch = self.scratch
        // Only its final status is read, from its own completion handler, after this take
        // has stopped writing.
        nonisolated(unsafe) let finishedWriter = writer
        nonisolated(unsafe) let this = self
        finishedWriter.finishWriting {
            let url = finishedWriter.status == .completed ? scratch : nil
            this.queue.async { this.settle(url) }
        }
    }

    private func settle(_ finished: URL?) {
        var url = finished
        if isAbandoned, let scratch = url {
            try? FileManager.default.removeItem(at: scratch)
            url = nil
        }
        outcome = .finished(url)
        let waiting = waiters
        waiters = []
        waiting.forEach { $0(url) }
    }

    /// Finishes the clip and moves it over the line's previous one.
    func commit(_ completion: @escaping @Sendable (URL?) -> Void) {
        let destination = self.destination
        finish { scratch in
            guard let scratch else {
                completion(nil)
                return
            }
            do {
                let manager = FileManager.default
                try manager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if manager.fileExists(atPath: destination.path) {
                    _ = try manager.replaceItemAt(destination, withItemAt: scratch)
                } else {
                    try manager.moveItem(at: scratch, to: destination)
                }
                completion(destination)
            } catch {
                try? FileManager.default.removeItem(at: scratch)
                completion(nil)
            }
        }
    }

    /// Stops writing and leaves nothing behind. The line's previous clip is not touched.
    func abandon() {
        isAbandoned = true
        switch outcome {
        case .writing:
            discardWriter()
            settle(nil)
        case .finishing:
            // The writer is closing; `settle` throws the file away when it is done.
            break
        case .finished(let url):
            if let url { try? FileManager.default.removeItem(at: url) }
            outcome = .finished(nil)
        }
    }

    private func discardWriter() {
        if let writer, writer.status == .writing { writer.cancelWriting() }
        try? FileManager.default.removeItem(at: scratch)
        writer = nil
        input = nil
        stash = nil
    }

    private func makeWriter(matching format: CMFormatDescription) -> Bool {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        guard dimensions.width > 0, dimensions.height > 0 else { return false }

        try? FileManager.default.removeItem(at: scratch)

        guard let writer = try? AVAssetWriter(outputURL: scratch, fileType: .mov) else {
            return false
        }

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(dimensions.width),
                AVVideoHeightKey: Int(dimensions.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 3_500_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
        )
        // Frames arrive at capture rate and cannot be waited for.
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }

        self.writer = writer
        self.input = input
        return true
    }
}
