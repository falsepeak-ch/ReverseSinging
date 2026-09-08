//
//  BoothRecorder.swift
//  ReverseSinging
//
//  The front-camera capture that rolls beside a dub take
//

import AVFoundation
import Combine
import CoreMedia

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
/// used to make, and it was still visible on playback.
final class BoothRecorder: NSObject, ObservableObject {

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
    /// shows a black rectangle where a face is about to be.
    @Published private(set) var isPreviewing = false
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

    /// Handed to `BoothPreviewView`. Owned here so the session outlives any view redraw.
    let session = AVCaptureSession()

    // MARK: Capture plumbing

    /// Everything below is touched only on this queue: the delegate callbacks arrive here,
    /// and every command from the main actor hops onto it first.
    private let captureQueue = DispatchQueue(label: "ch.falsepeak.dubloon.booth.capture")
    private let output = AVCaptureVideoDataOutput()
    /// Queue-confined, like everything else the session touches.
    private nonisolated(unsafe) var isConfigured = false

    /// The take being written, or the one waiting for its first frame. Queue-confined.
    private nonisolated(unsafe) var take: Take?

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

    /// Brings the preview up, asking for camera access if it has not been asked for yet.
    ///
    /// Safe to call on every appearance: configuration happens once, and starting a session
    /// that is already running is a no-op.
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

        // Configuring and running both happen on the capture queue, and so does every
        // delegate callback. A session reconfigured from the main thread while frames are
        // being delivered on another is the classic way to get an intermittent stall.
        let isRunning = await withCheckedContinuation { continuation in
            captureQueue.async {
                guard self.configureIfNeeded() else {
                    continuation.resume(returning: false)
                    return
                }
                if !self.session.isRunning { self.session.startRunning() }
                continuation.resume(returning: self.session.isRunning)
            }
        }

        availability = isRunning ? .ready : .unavailable
        isPreviewing = isRunning
    }

    /// Tears the preview down. Called when the record screen goes away, so the camera light
    /// is never on while the user is somewhere else in the app.
    func stop() {
        isPreviewing = false
        isWriting = false
        captureQueue.async { [session] in
            self.take?.abandon()
            self.take = nil
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - Configuration

    /// Wires the front camera in, once. Runs on `captureQueue`.
    ///
    /// - Returns: whether there is a usable front camera to preview at all. False on a
    ///   device without one, and on the Simulator, which has no capture device to offer.
    private nonisolated func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }

        // The one line that keeps this out of `AudioRecorder`'s way. Left at its default,
        // AVFoundation reconfigures the shared audio session when capture starts.
        session.automaticallyConfiguresApplicationAudioSession = false

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 720p, not 1080p. The booth is a corner inset or half a frame, never the whole of
        // one, and this roughly halves what a session costs on disk.
        session.sessionPreset = .hd1280x720

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ), let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            return false
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            // The app is portrait-locked, so the written file is too.
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            // The preview is mirrored to taste (see `BoothCamPreference.mirrorsPreview`); the
            // recording never is, so a shirt with writing on it reads correctly to whoever
            // ends up watching the clip.
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        isConfigured = true
        return true
    }

    // MARK: - Takes

    /// Begins writing a clip that starts at `anchorHostTime` and runs for `duration`.
    ///
    /// - Parameters:
    ///   - anchorHostTime: the `mach_absolute_time()` deadline the microphone opens on.
    ///   - duration: the line's length. Zero means "until told to stop".
    ///   - destination: where the clip lands. Overwritten if it already exists.
    func startTake(anchorHostTime: UInt64, duration: TimeInterval, to destination: URL) {
        guard availability == .ready, isPreviewing else { return }

        isWriting = true
        let anchor = CMClockMakeHostTimeFromSystemUnits(anchorHostTime)

        captureQueue.async {
            self.take?.abandon()
            self.take = Take(destination: destination, anchor: anchor, duration: duration)
        }
    }

    /// Closes the current clip and returns where it landed, or nil if nothing was written.
    ///
    /// A take that never received a frame produces no file rather than an empty one, so
    /// "is there booth footage for this line" stays a question about the filesystem.
    @discardableResult
    func finishTake() async -> URL? {
        isWriting = false

        return await withCheckedContinuation { continuation in
            captureQueue.async {
                guard let take = self.take else {
                    continuation.resume(returning: nil)
                    return
                }
                self.take = nil
                take.finish { continuation.resume(returning: $0) }
            }
        }
    }

    /// Drops the current clip without keeping it. For a take the user abandoned.
    func cancelTake() {
        isWriting = false
        captureQueue.async {
            self.take?.abandon()
            self.take = nil
        }
    }
}

// MARK: - Sample Buffer Delegate

extension BoothRecorder: AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Arrives on `captureQueue`, which is where every piece of writer state lives.
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let take else { return }

        if take.append(sampleBuffer) == .reachedEnd {
            // The line is over. Close on the capture clock rather than waiting for the UI to
            // notice, so every clip is exactly the stretch of film it belongs to.
            self.take = nil
            take.finish { _ in }
            Task { @MainActor [weak self] in self?.isWriting = false }
        }
    }
}

// MARK: - Take

/// One clip being written. Created and used only on `BoothRecorder.captureQueue`.
private final class Take {

    enum AppendResult { case ignored, written, reachedEnd }

    private let destination: URL
    private let anchor: CMTime
    private let duration: TimeInterval

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var hasStartedSession = false
    private var wroteAnything = false

    init(destination: URL, anchor: CMTime, duration: TimeInterval) {
        self.destination = destination
        self.anchor = anchor
        self.duration = duration
    }

    func append(_ sampleBuffer: CMSampleBuffer) -> AppendResult {
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Everything before the microphone opened belongs to the countdown, not the take.
        guard CMTimeCompare(presentation, anchor) >= 0 else { return .ignored }

        if duration > 0 {
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(presentation, anchor))
            if elapsed >= duration { return .reachedEnd }
        }

        // The writer is built from the first frame that counts, so its dimensions are the
        // ones the connection actually delivered rather than the ones the preset promised.
        if writer == nil {
            guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
                  makeWriter(matching: format) else { return .ignored }
        }

        guard let writer, let input, writer.status == .writing else { return .ignored }

        if !hasStartedSession {
            writer.startSession(atSourceTime: anchor)
            hasStartedSession = true
        }

        guard input.isReadyForMoreMediaData else { return .ignored }

        if input.append(sampleBuffer) {
            wroteAnything = true
            return .written
        }
        return .ignored
    }

    func finish(_ completion: @escaping (URL?) -> Void) {
        guard let writer, let input, writer.status == .writing, wroteAnything else {
            abandon()
            completion(nil)
            return
        }

        input.markAsFinished()
        let destination = self.destination
        writer.finishWriting {
            completion(writer.status == .completed ? destination : nil)
        }
    }

    /// Stops writing and leaves nothing behind.
    func abandon() {
        if let writer, writer.status == .writing { writer.cancelWriting() }
        try? FileManager.default.removeItem(at: destination)
        writer = nil
        input = nil
    }

    private func makeWriter(matching format: CMFormatDescription) -> Bool {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        guard dimensions.width > 0, dimensions.height > 0 else { return false }

        try? FileManager.default.removeItem(at: destination)

        guard let writer = try? AVAssetWriter(outputURL: destination, fileType: .mov) else {
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
