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

    typealias ProgressHandler = @Sendable (DubExportStage, Double) -> Void

    // MARK: - Full Export

    /// Mixes the user's takes over the backing track and wraps the result in an MP4.
    ///
    /// The picture is the pack's own video when it ships one; otherwise a slideshow of the
    /// per-line stills is rendered as a stand-in. Returns the finished file, ready to hand
    /// to a share sheet.
    func export(pack: DubPack, progress: ProgressHandler? = nil) async throws -> URL {
        let recorded = recordedLines(in: pack)
        guard !recorded.isEmpty else { throw DubExportError.nothingRecorded }

        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dubexport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workingDirectory) }

        let audioURL = workingDirectory.appendingPathComponent("mix.m4a")

        try await mixAudio(pack: pack, to: audioURL) { value in
            progress?(.mixingAudio, value)
        }

        let videoURL: URL
        if let sourceVideo = pack.videoURL {
            // Nothing to render — the mux is a passthrough remux of this track.
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
        let finalURL = try await mux(video: videoURL, audio: audioURL, pack: pack)
        progress?(.finishing, 1)

        await MainActor.run {
            AnalyticsManager.shared.trackDubExported(
                lineCount: pack.lines.count,
                recordedCount: recorded.count,
                duration: pack.duration
            )
        }

        return finalURL
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

            backingNode.volume = 0.75

            // Load first, then split: lines that overlap have to land on separate nodes or
            // they are queued rather than mixed. See `DubVoiceLanes`.
            let voiceSampleRate = DubAudioLoader.canonicalFormat.sampleRate

            // Placed by the same code the in-app scene player uses, so the file the user
            // shares is the mix they auditioned. See `DubVoiceAlignment`.
            let takes: [DubVoiceAlignment.Placement] = pack.lines.compactMap { line in
                let takeURL = pack.takeURL(for: line)
                guard FileManager.default.fileExists(atPath: takeURL.path),
                      let take = try? DubAudioLoader.loadVoiceBuffer(from: takeURL) else { return nil }

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
            // encoder. Installed before manual rendering is enabled — the engine must not be
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
    private func mux(video videoURL: URL, audio audioURL: URL, pack: DubPack) async throws -> URL {
        let composition = AVMutableComposition()

        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)

        if let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
           let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: sourceVideoTrack, at: .zero)
        }

        if let sourceAudioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
           let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            // Clamp to the video length so a long final take can't leave a black tail
            let duration = min(audioDuration, videoDuration)
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceAudioTrack, at: .zero)
        }

        let outputURL = AudioFileManager.shared.dubExportsDirectory()
            .appendingPathComponent("\(exportFilename(for: pack)).mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Both tracks are already H.264/AAC in MP4, so this is a remux rather than a re-encode
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw DubExportError.exportFailed(nil)
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4

        await session.exportAsync()

        guard session.status == .completed else {
            throw DubExportError.exportFailed(session.error)
        }

        return outputURL
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
