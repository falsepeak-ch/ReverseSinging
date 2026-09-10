//
//  DubMixer.swift
//  ReverseSinging
//
//  Renders a finished dub: audio mix, slideshow video, muxed MP4
//

import AVFoundation
import UIKit

nonisolated enum DubExportError: LocalizedError {
    case nothingRecorded
    case renderSetupFailed
    case writerFailed(Error?)
    case exportFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .nothingRecorded:
            return Strings.Dub.Error.nothingRecorded
        case .renderSetupFailed:
            return String(format: Strings.Dub.Error.exportFailed, "audio engine setup")
        case .writerFailed(let error):
            return String(format: Strings.Dub.Error.exportFailed, error?.localizedDescription ?? "video writer")
        case .exportFailed(let error):
            return String(format: Strings.Dub.Error.exportFailed, error?.localizedDescription ?? "unknown")
        }
    }
}

/// Stages of an export, so the UI can say what's happening rather than just spinning.
nonisolated enum DubExportStage: Equatable {
    case mixingAudio
    case renderingVideo
    case finishing

    var message: String {
        switch self {
        case .mixingAudio: return Strings.Dub.exportMixing
        case .renderingVideo: return Strings.Dub.exportRendering
        case .finishing: return Strings.Dub.exporting
        }
    }
}

nonisolated struct DubMixer {

    static let shared = DubMixer()

    private init() {}

    /// Slideshow frame rate. The stills only change ~60 times in a scene, but a steady rate
    /// keeps the file playable everywhere; repeated frames cost the encoder almost nothing
    /// because each image is drawn once and its pixel buffer re-appended.
    private static let frameRate: Int32 = 10
    private static let videoSize = CGSize(width: 1280, height: 720)
    private static let outputSampleRate: Double = 44_100
    /// Stands in for a booth clip while working out the strip's band, which does not depend on
    /// it. The real clip's size is read by the composer.
    private static let boothPlaceholderSize = CGSize(width: 720, height: 1280)

    typealias ProgressHandler = @Sendable (DubExportStage, Double) -> Void

    // MARK: - Full Export

    /// Mixes the user's takes over the backing track and wraps the result in a shareable MP4.
    ///
    /// The picture is the pack's own video when it ships one; otherwise a slideshow of the
    /// per-line stills is rendered as a stand-in. Returns the finished file, ready to hand
    /// to a share sheet.
    ///
    /// - Parameters:
    ///   - cut: which stretch of the film to export. Defaults to the whole scene, which is
    ///     what Export has always produced.
    ///   - frame: how the booth sits in it. `.off` keeps the export a remux; anything else
    ///     means a re-encode, and takes correspondingly longer.
    ///   - includesBooth: whether the performer's footage goes in. Off still reshapes a
    ///     vertical frame and draws its waveform strip; it only leaves the face out.
    func export(
        pack: DubPack,
        cut: DubCut = .fullScene,
        frame: DubBoothFrame = .off,
        includesBooth: Bool = true,
        progress: ProgressHandler? = nil
    ) async throws -> URL {
        let recorded = recordedLines(in: pack)
        guard !recorded.isEmpty else { throw DubExportError.nothingRecorded }

        let segments = DubCutPlanner.segments(
            for: cut,
            pack: pack,
            recordedSlugs: Set(recorded.map(\.slug))
        )
        guard !segments.isEmpty else { throw DubExportError.nothingRecorded }

        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dubexport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workingDirectory) }

        let audioURL = workingDirectory.appendingPathComponent("mix.m4a")

        try await mixAudio(pack: pack, to: audioURL) { value in
            progress?(.mixingAudio, value)
        }

        // The mix covers the scene; the export plays a cut of it. See `DubAudioCut`.
        let cutAudioURL = try DubAudioCut.cut(audioURL, to: segments, in: workingDirectory)

        let videoURL: URL
        if let sourceVideo = pack.videoURL {
            // Nothing to render. The picture is the pack's own track.
            progress?(.renderingVideo, 1)
            videoURL = sourceVideo
        } else {
            let slideshowURL = workingDirectory.appendingPathComponent("slideshow.mp4")
            try await renderSlideshow(pack: pack, to: slideshowURL) { value in
                progress?(.renderingVideo, value)
            }
            videoURL = slideshowURL
        }

        progress?(.finishing, 0)

        // Only the vertical frames carry a strip, and sampling every take to render one
        // nobody will see is the most expensive no-op in the export.
        var waveURL: URL?
        if frame.isVertical,
           let band = DubBoothLayout.make(
               frame: frame,
               // The same shape the composer will lay the strip out against, so the clip is
               // rendered at exactly the size of the band it goes into.
               sceneDisplaySize: await DubBoothComposer.sceneDisplaySize(of: pack) ?? Self.videoSize,
               boothDisplaySize: Self.boothPlaceholderSize
           ).waveRect {
            let bars = await DubWaveOverlay.bars(pack: pack, segments: segments)
            let url = workingDirectory.appendingPathComponent("wave.mp4")
            try await DubWaveOverlay.renderStrip(
                bars: bars,
                labels: (Strings.Dub.original, Strings.Dub.myDub),
                size: band.size,
                duration: segments.reduce(0) { $0 + $1.duration },
                to: url
            )
            waveURL = url
        }

        let composed = try await DubBoothComposer.compose(
            pack: pack,
            segments: segments,
            frame: frame,
            includesBooth: includesBooth,
            sceneVideo: videoURL,
            audio: cutAudioURL,
            boothClips: boothClips(in: pack),
            waveVideo: waveURL
        )

        let finalURL = try await write(composed, pack: pack, progress: progress)
        progress?(.finishing, 1)

        await MainActor.run {
            AnalyticsManager.shared.trackDubExported(
                lineCount: pack.lines.count,
                recordedCount: recorded.count,
                duration: composed.duration.seconds
            )
            AnalyticsManager.shared.trackCustomEvent(
                name: "dub_export_shape",
                parameters: [
                    "cut": cut.analyticsName,
                    "booth_frame": frame.rawValue,
                    "booth_included": includesBooth
                ]
            )
        }

        return finalURL
    }

    /// The booth footage that exists for this pack, by line slug.
    func boothClips(in pack: DubPack) -> [String: URL] {
        var clips: [String: URL] = [:]
        for line in pack.lines where pack.hasBoothTake(for: line) {
            clips[line.slug] = pack.boothTakeURL(for: line)
        }
        return clips
    }

    func recordedLines(in pack: DubPack) -> [DubLine] {
        pack.lines.filter { FileManager.default.fileExists(atPath: pack.takeURL(for: $0).path) }
    }

    // MARK: - Audio Mix

    /// Offline render of backing track + every take at its timestamp.
    ///
    /// Uses the engine's manual rendering mode rather than realtime playback, so a 5-minute
    /// scene mixes in a couple of seconds instead of 5 minutes.
    func mixAudio(pack: DubPack, to outputURL: URL, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        try await Task.detached(priority: .userInitiated) {
            let engine = AVAudioEngine()
            let backingNode = AVAudioPlayerNode()

            engine.attach(backingNode)

            let backingBuffer = pack.backingTrackURL.flatMap { try? DubAudioLoader.loadBuffer(from: $0) }

            if let backingBuffer {
                engine.connect(backingNode, to: engine.mainMixerNode, format: backingBuffer.format)
            }

            // One level for the whole scene, set against this scene's own dialogue rather
            // than by a fixed number, so a feature's music stem and a 1951 short's both end
            // up in the same place. See `DubBackingBalance`.
            backingNode.volume = backingBuffer.map {
                DubBackingBalance.bedGain(for: $0, in: pack)
            } ?? DubBackingBalance.fallbackBedGain

            // Load first, then split: lines that overlap have to land on separate nodes or
            // they are queued rather than mixed. See `DubVoiceLanes`.
            let voiceSampleRate = DubAudioLoader.canonicalFormat.sampleRate

            // Placed by the same code the in-app scene player uses, so the file the user
            // shares is the mix they auditioned. See `DubVoiceAlignment`.
            let takes: [DubVoiceAlignment.Placement] = pack.lines.compactMap { line in
                let takeURL = pack.takeURL(for: line)
                guard FileManager.default.fileExists(atPath: takeURL.path),
                      let take = try? DubAudioLoader.loadVoiceBuffer(from: takeURL) else { return nil }

                // The room this take was recorded in, held down between its words, so the
                // scene's noise floor does not step at every line boundary. Before the level
                // match, which would otherwise scale each take's room along with its voice.
                DubTakeCleanup.apply(to: take)

                // Brought up to the level the film played this line at, so the scene arrives
                // at one volume rather than at whatever each take was recorded at.
                DubVoiceLevel.match(take, toReferenceAt: pack.referenceAudioURL(for: line))

                return DubVoiceAlignment.place(
                    take: take,
                    for: line,
                    referenceURL: pack.referenceAudioURL(for: line)
                )
            }

            let lanes = DubVoiceLanes.assign(
                takes,
                start: { $0.startTime },
                end: { $0.endTime(sampleRate: voiceSampleRate) }
            )

            let voiceNodes: [AVAudioPlayerNode] = lanes.map { _ in
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: DubAudioLoader.canonicalFormat)
                node.volume = 1.0
                return node
            }

            guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: Self.outputSampleRate, channels: 2) else {
                throw DubExportError.renderSetupFailed
            }

            // Voices sum, so the mix can add up past full scale before it reaches the
            // encoder. Installed before manual rendering is enabled. The engine must not be
            // running while its output is rewired.
            DubMasterLimiter.install(in: engine)

            let maximumFrameCount: AVAudioFrameCount = 4096
            try engine.enableManualRenderingMode(.offline, format: outputFormat, maximumFrameCount: maximumFrameCount)
            try engine.start()

            if let backingBuffer {
                backingNode.scheduleBuffer(backingBuffer, at: nil, options: [])
            }

            var latestVoiceEnd: TimeInterval = 0

            for (laneIndex, lane) in lanes.enumerated() {
                for take in lane {
                    let time = AVAudioTime(
                        sampleTime: AVAudioFramePosition(take.startTime * voiceSampleRate),
                        atRate: voiceSampleRate
                    )
                    voiceNodes[laneIndex].scheduleBuffer(take.buffer, at: time, options: [])

                    latestVoiceEnd = max(latestVoiceEnd, take.endTime(sampleRate: voiceSampleRate))
                }
            }

            // Starting a player node that was never connected (no backing track, or one
            // AVFoundation can't read) raises inside AVAudioEngine
            if backingBuffer != nil { backingNode.play() }
            voiceNodes.forEach { $0.play() }

            // Long takes are allowed to run past the backing track rather than being clipped
            let totalDuration = max(pack.duration, latestVoiceEnd)
            let totalFrames = AVAudioFramePosition(totalDuration * outputFormat.sampleRate)

            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: Self.outputSampleRate,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192_000
            ]
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: settings)

            guard let renderBuffer = AVAudioPCMBuffer(
                pcmFormat: engine.manualRenderingFormat,
                frameCapacity: maximumFrameCount
            ) else {
                throw DubExportError.renderSetupFailed
            }

            while engine.manualRenderingSampleTime < totalFrames {
                let remaining = totalFrames - engine.manualRenderingSampleTime
                let framesToRender = AVAudioFrameCount(min(AVAudioFramePosition(renderBuffer.frameCapacity), remaining))

                let status = try engine.renderOffline(framesToRender, to: renderBuffer)

                switch status {
                case .success:
                    try outputFile.write(from: renderBuffer)
                    progress?(Double(engine.manualRenderingSampleTime) / Double(totalFrames))
                case .insufficientDataFromInputNode:
                    continue
                case .cannotDoInCurrentContext, .error:
                    throw DubExportError.renderSetupFailed
                @unknown default:
                    throw DubExportError.renderSetupFailed
                }
            }

            engine.stop()
            engine.disableManualRenderingMode()
            progress?(1.0)
        }.value
    }

    // MARK: - Slideshow Video

    /// Writes a silent H.264 slideshow: each line's still held for its stretch of the timeline.
    func renderSlideshow(pack: DubPack, to outputURL: URL, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        try await Task.detached(priority: .userInitiated) {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(Self.videoSize.width),
                AVVideoHeightKey: Int(Self.videoSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 4_000_000,
                    AVVideoMaxKeyFrameIntervalKey: Int(Self.frameRate) * 2
                ]
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = false

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                    kCVPixelBufferWidthKey as String: Int(Self.videoSize.width),
                    kCVPixelBufferHeightKey as String: Int(Self.videoSize.height)
                ]
            )

            guard writer.canAdd(input) else { throw DubExportError.writerFailed(nil) }
            writer.add(input)

            guard writer.startWriting() else { throw DubExportError.writerFailed(writer.error) }
            writer.startSession(atSourceTime: .zero)

            let totalFrames = max(1, Int(pack.duration * Double(Self.frameRate)))

            // Only redraw when the visible line changes: ~60 image decodes for a whole scene,
            // with the same pixel buffer re-appended for every frame in between.
            var currentSlug: String?
            var currentPixelBuffer: CVPixelBuffer?

            for frame in 0..<totalFrames {
                let time = Double(frame) / Double(Self.frameRate)
                let line = pack.line(at: time)

                if line?.slug != currentSlug || currentPixelBuffer == nil {
                    currentSlug = line?.slug
                    let imageURL = line.map { pack.imageURL(for: $0) } ?? pack.iconURL
                    currentPixelBuffer = Self.makePixelBuffer(from: imageURL, pool: adaptor.pixelBufferPool)
                }

                guard let pixelBuffer = currentPixelBuffer else { continue }

                while !input.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 5_000_000)
                }

                let presentationTime = CMTime(value: CMTimeValue(frame), timescale: Self.frameRate)
                if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                    throw DubExportError.writerFailed(writer.error)
                }

                if frame % Int(Self.frameRate) == 0 {
                    progress?(Double(frame) / Double(totalFrames))
                }
            }

            input.markAsFinished()

            await withCheckedContinuation { continuation in
                writer.finishWriting { continuation.resume() }
            }

            if writer.status != .completed {
                throw DubExportError.writerFailed(writer.error)
            }

            progress?(1.0)
        }.value
    }

    /// Draws a still into a pixel buffer, aspect-fit on black so odd-sized packs don't stretch.
    private static func makePixelBuffer(from imageURL: URL, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let image = UIImage(contentsOfFile: imageURL.path) else { return nil }

        var pixelBuffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        } else {
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(videoSize.width),
                Int(videoSize.height),
                kCVPixelFormatType_32ARGB,
                [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary,
                &pixelBuffer
            )
        }

        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(videoSize.width),
            height: Int(videoSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ), let cgImage = image.cgImage else {
            return nil
        }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: videoSize))

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = min(videoSize.width / imageSize.width, videoSize.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (videoSize.width - drawSize.width) / 2,
            y: (videoSize.height - drawSize.height) / 2
        )

        context.draw(cgImage, in: CGRect(origin: origin, size: drawSize))

        return buffer
    }

    // MARK: - Mux

    /// Combines the silent slideshow and the audio mix into the file the user shares.
    /// Writes the composition out.
    ///
    /// Passthrough when there is nothing to composite, which is every export that does not use
    /// the booth: both tracks are already H.264/AAC in MP4, so it is a remux and costs almost
    /// nothing. A booth frame means a real re-encode, because the picture is being rebuilt.
    private func write(
        _ composed: DubBoothComposer.Composed,
        pack: DubPack,
        progress: ProgressHandler? = nil
    ) async throws -> URL {
        let outputURL = AudioFileManager.shared.dubExportsDirectory()
            .appendingPathComponent("\(exportFilename(for: pack)).mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Nothing to composite: both tracks are already H.264/AAC in an MP4, so this is a
        // remux and the export session does it without touching a single pixel.
        guard let videoComposition = composed.videoComposition else {
            guard let session = AVAssetExportSession(
                asset: composed.composition,
                presetName: AVAssetExportPresetPassthrough
            ) else { throw DubExportError.exportFailed(nil) }

            session.outputURL = outputURL
            session.outputFileType = .mp4
            await session.exportAsync()

            guard session.status == .completed else {
                throw DubExportError.exportFailed(session.error)
            }
            return outputURL
        }

        try await encode(composed.composition, through: videoComposition, to: outputURL, progress: progress)
        return outputURL
    }

    /// Re-encodes a composited export, choosing the encoder's settings rather than inheriting
    /// them.
    ///
    /// **`AVAssetExportPresetHighestQuality` is the wrong tool for this**, which is what it was
    /// doing before: it takes the word "highest" literally and gave a 35-second dub of a
    /// 140 kbit 480x360 transfer an 11.6 Mbit/s bitrate and a 50 MB file. None of that is
    /// picture — the source has no such detail to carry — it is just time in the encoder and
    /// minutes in an upload. A preset also cannot be told a bitrate, so the only way to pick
    /// one is to drive the reader and the writer directly, which is also what makes the
    /// progress bar report the render instead of guessing at it.
    private func encode(
        _ asset: AVAsset,
        through videoComposition: AVVideoComposition,
        to outputURL: URL,
        progress: ProgressHandler?
    ) async throws {
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let size = videoComposition.renderSize
        let frameRate = videoComposition.frameDuration.seconds > 0
            ? 1 / videoComposition.frameDuration.seconds
            : 30

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else { throw DubExportError.renderSetupFailed }

        // BGRA rather than the encoder's own YUV. Asking the compositor for YUV looks like it
        // should save the conversion and measurably does not — it renders in BGRA regardless
        // and converts on the way out, so requesting YUV buys a second conversion, not none.
        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: videoTracks,
            videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
        )
        videoOutput.videoComposition = videoComposition
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else { throw DubExportError.renderSetupFailed }
        reader.add(videoOutput)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: Self.bitRate(for: size, frameRate: frameRate),
                    AVVideoMaxKeyFrameIntervalKey: Int(frameRate.rounded()) * 2,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
        )
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else { throw DubExportError.renderSetupFailed }
        writer.add(videoInput)

        // Copied across, not decoded and encoded again. The mix is already AAC in an MP4 and
        // nothing in this pass touches a sample of it, so a second encode would cost a couple
        // of seconds to make it very slightly worse.
        //
        // **The format hint is what makes that work.** A writer input with no output settings
        // is asking to pass compressed samples straight through, and it cannot do that until
        // it knows what they are; without the hint it accepts every sample and writes no
        // track at all. Silently — which is how the first version of this shipped an export
        // with no sound in it, so the wiring is checked rather than assumed from here on.
        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let formats = try await audioTrack.load(.formatDescriptions)

            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            output.alwaysCopiesSampleData = false

            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: nil,
                sourceFormatHint: formats.first
            )
            input.expectsMediaDataInRealTime = false

            guard formats.first != nil, reader.canAdd(output), writer.canAdd(input) else {
                throw DubExportError.renderSetupFailed
            }
            reader.add(output)
            writer.add(input)
            audioOutput = output
            audioInput = input
        }

        guard writer.startWriting() else { throw DubExportError.writerFailed(writer.error) }
        guard reader.startReading() else { throw DubExportError.exportFailed(reader.error) }
        writer.startSession(atSourceTime: .zero)

        let duration = try await asset.load(.duration).seconds

        async let video: Void = pump(videoOutput, into: videoInput, label: "video") { time in
            guard duration > 0 else { return }
            progress?(.finishing, min(max(time / duration, 0), 1))
        }
        async let audio: Void = {
            guard let audioOutput, let audioInput else { return }
            await pump(audioOutput, into: audioInput, label: "audio", onTime: nil)
        }()

        _ = await (video, audio)

        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }

        if reader.status == .failed { throw DubExportError.exportFailed(reader.error) }
        guard writer.status == .completed else { throw DubExportError.writerFailed(writer.error) }
    }

    /// Moves every sample an output has into an input, waiting on the input rather than
    /// spinning on it.
    private func pump(
        _ output: AVAssetReaderOutput,
        into input: AVAssetWriterInput,
        label: String,
        onTime: (@Sendable (TimeInterval) -> Void)?
    ) async {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "ch.falsepeak.dubloon.export.\(label)")
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard let sample = output.copyNextSampleBuffer() else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                    onTime?(CMSampleBufferGetPresentationTimeStamp(sample).seconds)
                    if !input.append(sample) {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
    }

    /// Bits per second for a frame of this size at this rate.
    ///
    /// About 0.12 bits per pixel per frame, which is roughly what a streaming service spends
    /// on H.264 at these sizes and comfortably more than the source material carries. Floored
    /// so a small frame still gets a usable rate.
    private static func bitRate(for size: CGSize, frameRate: Double) -> Int {
        let pixels = Double(size.width * size.height)
        return max(2_000_000, Int(pixels * frameRate * 0.12))
    }

    private func exportFilename(for pack: DubPack) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"

        let title = pack.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")

        return "\(title.isEmpty ? "dub" : title)-\(formatter.string(from: Date()))"
    }
}


// MARK: - Export Compatibility

private extension AVAssetExportSession {
    /// `export(to:as:)` is iOS 18+; the app ships to iOS 17.
    func exportAsync() async {
        await withCheckedContinuation { continuation in
            exportAsynchronously { continuation.resume() }
        }
    }
}
