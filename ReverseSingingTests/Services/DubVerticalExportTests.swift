//
//  DubVerticalExportTests.swift
//  ReverseSingingTests
//
//  The Vertical post and the Dubloon mark, rendered through the export path
//

import Testing
import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ReverseSinging
import DubCompositing
import DubAudio

/// Renders real compositions with synthetic footage (the Simulator has no camera) and reads
/// the pixels back. A red scene and a blue booth make the geometry unambiguous; the mark is
/// cream, the only thing in either fixture with any green in it.
@Suite("Vertical Export", .serialized)
struct DubVerticalExportTests {

    // MARK: Fixtures

    private static let sceneSize = CGSize(width: 640, height: 360)
    private static let boothSize = CGSize(width: 360, height: 640)

    private func makePack(lineStart: TimeInterval = 0, lineDuration: TimeInterval, sceneDuration: TimeInterval) -> (DubPack, DubLine) {
        let line = DubLine(
            index: 1,
            slug: "001_Tester",
            character: "Tester",
            caption: "line",
            imageFile: "x.jpg",
            referenceAudioFile: "x.wav",
            startTime: lineStart,
            duration: lineDuration
        )
        let pack = DubPack(
            title: "Vertical Export",
            authors: [],
            iconFile: "x.jpg",
            backingTrackFile: nil,
            folderName: "vertical-export",
            lines: [line],
            duration: sceneDuration
        )
        return (pack, line)
    }

    private func scratch() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vertical-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func compose(
        frame: DubBoothFrame,
        includesBooth: Bool = true,
        corner: DubPipCorner = .bottomRight,
        in directory: URL
    ) async throws -> DubBoothComposer.Composed {
        let sceneURL = directory.appendingPathComponent("scene.mp4")
        let boothURL = directory.appendingPathComponent("booth.mov")
        try await SyntheticClip.solid(size: Self.sceneSize, duration: 1, red: true, to: sceneURL)
        try await SyntheticClip.solid(size: Self.boothSize, duration: 1, red: false, to: boothURL)

        let (pack, line) = makePack(lineDuration: 1, sceneDuration: 1)
        return try await DubBoothComposer.compose(
            pack: pack,
            segments: DubCutPlanner.segments(for: .fullScene, pack: pack, recordedSlugs: [line.slug]),
            frame: frame,
            includesBooth: includesBooth,
            sceneVideo: sceneURL,
            audio: sceneURL,
            boothClips: [line.slug: boothURL],
            pipCorner: corner
        )
    }

    private func grab(_ composed: DubBoothComposer.Composed, at seconds: Double = 0.5) throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: composed.composition)
        generator.videoComposition = composed.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
    }

    private func layout(_ frame: DubBoothFrame, corner: DubPipCorner = .bottomRight) -> DubBoothLayout {
        DubBoothLayout.make(
            frame: frame,
            sceneDisplaySize: Self.sceneSize,
            boothDisplaySize: Self.boothSize,
            pipCorner: corner,
            watermarkAspect: DubWatermark.aspect(of: DubWatermark.image())
        )
    }

    // MARK: Vertical

    @Test func theVerticalPostLetterboxesTheSceneAndPutsTheBoothInTheLowerBar() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let composed = try await compose(frame: .vertical, in: directory)
        let image = try grab(composed)
        let layout = layout(.vertical)
        let pip = try #require(layout.boothRect)
        let pixels = Pixels(image)

        #expect(composed.videoComposition.renderSize == CGSize(width: 1080, height: 1920))
        #expect(pixels.colour(at: CGPoint(x: 540, y: 960)) == .red, "the scene is in the middle")
        #expect(pixels.colour(at: CGPoint(x: 540, y: layout.sceneRect.maxY + 30)) == .black, "with a black bar under it")
        #expect(pixels.colour(at: CGPoint(x: pip.midX, y: pip.midY)) == .blue, "the booth is in its corner")
        #expect(pip.minY > layout.sceneRect.maxY, "inside the lower bar")
        #expect(pixels.colour(at: CGPoint(x: pip.minX + 2, y: pip.maxY - 2)) != .blue,
                "and its corners are rounded off")
    }

    @Test func theCornerChoiceIsHonoured() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let composed = try await compose(frame: .vertical, corner: .topRight, in: directory)
        let pixels = Pixels(try grab(composed))
        let pip = try #require(layout(.vertical, corner: .topRight).boothRect)

        #expect(pixels.colour(at: CGPoint(x: pip.midX, y: pip.midY)) == .blue)
        #expect(pixels.colour(at: CGPoint(x: 1080 - pip.midX, y: 1920 - pip.midY)) == .black,
                "nothing left behind in the default corner")
    }

    @Test func withoutBoothFootageVerticalIsTheSceneLetterboxedAlone() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let composed = try await compose(frame: .vertical, includesBooth: false, in: directory)
        let pixels = Pixels(try grab(composed))
        let pip = try #require(layout(.vertical).boothRect)

        #expect(composed.videoComposition.renderSize == CGSize(width: 1080, height: 1920))
        #expect(pixels.colour(at: CGPoint(x: 540, y: 960)) == .red)
        #expect(pixels.colour(at: CGPoint(x: pip.midX, y: pip.midY)) == .black, "no picture-in-picture")
    }

    // MARK: Watermark

    /// Every frame carries the mark in its corner, and nowhere else.
    @Test func everyFormatCarriesTheMarkInItsCorner() async throws {
        try #require(DubWatermark.image() != nil, "the icon-lettering asset must load from the app bundle")

        for frame in DubBoothFrame.allCases {
            let directory = try scratch()
            defer { try? FileManager.default.removeItem(at: directory) }

            let composed = try await compose(frame: frame, in: directory)
            let pixels = Pixels(try grab(composed))
            let layout = layout(frame)

            #expect(pixels.greenest(in: layout.watermarkRect) > 90, "\(frame): the mark is missing")
            #expect(pixels.greenest(in: CGRect(
                x: layout.sceneRect.midX - 10, y: layout.sceneRect.midY - 10, width: 20, height: 20
            )) < 50, "\(frame): and it is not over the middle of the picture")
        }
    }

    @Test func theMarkIsTranslucent() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let pixels = Pixels(try grab(try await compose(frame: .vertical, in: directory)))
        let mark = layout(.vertical).watermarkRect
        // The lettering's cream is ~235 green at full strength.
        #expect(pixels.greenest(in: mark) < 215)
    }

    // MARK: Through the encoder

    /// The export's own last step, end to end: composition, compositor, encoder, file. Also
    /// writes the sample the Vertical format is reviewed from, when asked to.
    @Test func aVerticalExportEncodesWithTheBoothTheMarkAndTheSound() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let environment = ProcessInfo.processInfo.environment
        let sceneDuration: TimeInterval = 8
        let line = (start: 1.5, duration: 5.0)

        let sceneURL = directory.appendingPathComponent("scene.mp4")
        let boothURL = directory.appendingPathComponent("booth.mov")
        let audioURL = directory.appendingPathComponent("mix.m4a")

        let stills = environment["DUBLOON_SAMPLE_STILLS"].map { URL(fileURLWithPath: $0) }
        try await SyntheticClip.scene(stills: stills, size: SyntheticClip.sceneSize(for: stills), duration: sceneDuration, to: sceneURL)
        try await SyntheticClip.performer(size: CGSize(width: 720, height: 1280), duration: line.duration, to: boothURL)
        if let audio = environment["DUBLOON_SAMPLE_AUDIO"] {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: audio), to: audioURL)
        } else {
            try SyntheticClip.tone(duration: sceneDuration, to: audioURL)
        }

        let (pack, dubLine) = makePack(lineStart: line.start, lineDuration: line.duration, sceneDuration: sceneDuration)
        let segments = DubCutPlanner.segments(for: .fullScene, pack: pack, recordedSlugs: [dubLine.slug])
        let cutAudio = try DubAudioCut.cut(audioURL, to: segments, in: directory)

        let composed = try await DubBoothComposer.compose(
            pack: pack,
            segments: segments,
            frame: .vertical,
            sceneVideo: sceneURL,
            audio: cutAudio,
            boothClips: [dubLine.slug: boothURL]
        )

        let output = directory.appendingPathComponent("vertical.mp4")
        try await DubMixer.shared.render(composed, to: output)

        let asset = AVURLAsset(url: output)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await video.load(.naturalSize)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration).seconds

        #expect(size == CGSize(width: 1080, height: 1920))
        #expect(!audioTracks.isEmpty, "the dub's sound came through")
        #expect(abs(duration - sceneDuration) < 0.3)

        // In the middle of the line: the performer is in the corner.
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let frame = try generator.copyCGImage(at: CMTime(seconds: line.start + 2, preferredTimescale: 600), actualTime: nil)
        let pip = try #require(DubBoothLayout.make(
            frame: .vertical,
            sceneDisplaySize: CGSize(width: 1280, height: 720),
            boothDisplaySize: CGSize(width: 720, height: 1280)
        ).boothRect)
        #expect(Pixels(frame).brightness(at: CGPoint(x: pip.midX, y: pip.midY)) > 40, "the booth is in the file")

        // Before the line, the corner is empty: the booth only rolls for a take.
        let before = try generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil)
        #expect(Pixels(before).brightness(at: CGPoint(x: pip.midX, y: pip.midY)) < 20)

        if let destination = environment["DUBLOON_SAMPLE_DIR"] {
            let folder = URL(fileURLWithPath: destination, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let video = folder.appendingPathComponent("vertical-export-sample.mp4")
            try? FileManager.default.removeItem(at: video)
            try FileManager.default.copyItem(at: output, to: video)
            try SyntheticClip.writePNG(frame, to: folder.appendingPathComponent("vertical-export-sample-frame.png"))

            // And the same take in the landscape corner frame, to show the mark opposite the
            // inset there.
            let corner = try await DubBoothComposer.compose(
                pack: pack,
                segments: segments,
                frame: .corner,
                sceneVideo: sceneURL,
                audio: cutAudio,
                boothClips: [dubLine.slug: boothURL]
            )
            let cornerGenerator = AVAssetImageGenerator(asset: corner.composition)
            cornerGenerator.videoComposition = corner.videoComposition
            let cornerFrame = try cornerGenerator.copyCGImage(at: CMTime(seconds: line.start + 2, preferredTimescale: 600), actualTime: nil)
            try SyntheticClip.writePNG(cornerFrame, to: folder.appendingPathComponent("corner-export-sample-frame.png"))
        }
    }
}

// MARK: - Pixels

private struct Pixels {
    enum Colour { case red, blue, black, other }

    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        if let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        self.bytes = bytes
    }

    private func rgb(_ point: CGPoint) -> (Int, Int, Int) {
        let x = min(max(Int(point.x), 0), width - 1)
        let y = min(max(Int(point.y), 0), height - 1)
        let offset = y * width * 4 + x * 4
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
    }

    func colour(at point: CGPoint) -> Colour {
        let (r, g, b) = rgb(point)
        if r < 30, g < 30, b < 30 { return .black }
        if r > b + 40, r > g + 40 { return .red }
        if b > r + 40, b > g + 40 { return .blue }
        return .other
    }

    func brightness(at point: CGPoint) -> Int {
        let (r, g, b) = rgb(point)
        return max(r, g, b)
    }

    func greenest(in rect: CGRect) -> Int {
        var peak = 0
        for y in stride(from: max(0, Int(rect.minY)), to: min(height, Int(rect.maxY)), by: 2) {
            for x in stride(from: max(0, Int(rect.minX)), to: min(width, Int(rect.maxX)), by: 2) {
                peak = max(peak, rgb(CGPoint(x: x, y: y)).1)
            }
        }
        return peak
    }
}

// MARK: - Synthetic Footage

/// Clips made in code, because the Simulator has no camera and the tests have no films.
enum SyntheticClip {

    /// 1280 wide, at the stills' own shape (a 2.39:1 scope pack stays scope), or 16:9.
    static func sceneSize(for directory: URL?) -> CGSize {
        let first = (directory.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) } ?? [])
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first
        guard let first,
              let source = CGImageSourceCreateWithURL(first as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0 else { return CGSize(width: 1280, height: 720) }
        let height = (1280 * CGFloat(image.height) / CGFloat(image.width) / 2).rounded() * 2
        return CGSize(width: 1280, height: height)
    }

    static func solid(size: CGSize, duration: TimeInterval, red: Bool, to url: URL) async throws {
        try await write(size: size, duration: duration, fps: 10, to: url) { context, _ in
            context.setFillColor(red ? CGColor(red: 1, green: 0, blue: 0, alpha: 1) : CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// The film: the given stills one after another (a pack's own shots, for a sample that
    /// looks like Dubloon), or a slow gradient when there are none.
    static func scene(stills directory: URL?, size: CGSize, duration: TimeInterval, to url: URL) async throws {
        let images: [CGImage] = (directory.flatMap {
            try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
        } ?? [])
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            }

        try await write(size: size, duration: duration, fps: 24, to: url) { context, time in
            let bounds = CGRect(origin: .zero, size: size)
            if images.isEmpty {
                let hue = CGFloat(time / duration)
                context.setFillColor(CGColor(red: 0.2 + 0.5 * hue, green: 0.25, blue: 0.5 - 0.3 * hue, alpha: 1))
                context.fill(bounds)
            } else {
                let image = images[min(images.count - 1, Int(time / duration * Double(images.count)))]
                // A slow push in, so the picture is visibly moving.
                let zoom = 1 + 0.06 * CGFloat(time.truncatingRemainder(dividingBy: duration / Double(images.count)))
                let scale = max(size.width / CGFloat(image.width), size.height / CGFloat(image.height)) * zoom
                let drawn = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
                context.draw(image, in: CGRect(
                    x: (size.width - drawn.width) / 2,
                    y: (size.height - drawn.height) / 2,
                    width: drawn.width,
                    height: drawn.height
                ))
            }
        }
    }

    /// A stand-in for the front camera: a lit backdrop and a simple figure whose mouth opens
    /// and closes, so motion and timing are visible in the file.
    static func performer(size: CGSize, duration: TimeInterval, to url: URL) async throws {
        try await write(size: size, duration: duration, fps: 30, to: url) { context, time in
            let bounds = CGRect(origin: .zero, size: size)
            let colors = [
                CGColor(red: 0.20, green: 0.24, blue: 0.30, alpha: 1),
                CGColor(red: 0.42, green: 0.30, blue: 0.26, alpha: 1)
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }

            let sway = CGFloat(sin(time * 1.6)) * size.width * 0.02
            let centre = CGPoint(x: bounds.midX + sway, y: size.height * 0.56)
            let head = size.width * 0.24

            // Shoulders.
            context.setFillColor(CGColor(red: 0.78, green: 0.22, blue: 0.18, alpha: 1))
            context.fillEllipse(in: CGRect(x: centre.x - head * 1.7, y: -head * 0.6, width: head * 3.4, height: head * 2.4))
            // Head.
            context.setFillColor(CGColor(red: 0.93, green: 0.80, blue: 0.66, alpha: 1))
            context.fillEllipse(in: CGRect(x: centre.x - head, y: centre.y - head * 1.15, width: head * 2, height: head * 2.3))
            // Eyes.
            context.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
            for side in [-1.0, 1.0] {
                context.fillEllipse(in: CGRect(x: centre.x + CGFloat(side) * head * 0.38 - head * 0.09, y: centre.y + head * 0.25, width: head * 0.18, height: head * 0.2))
            }
            // Mouth, talking.
            let open = head * (0.06 + 0.22 * CGFloat(abs(sin(time * 9))))
            context.setFillColor(CGColor(red: 0.35, green: 0.08, blue: 0.10, alpha: 1))
            context.fillEllipse(in: CGRect(x: centre.x - head * 0.3, y: centre.y - head * 0.55 - open / 2, width: head * 0.6, height: open))
        }
    }

    /// A quiet two-tone hum standing in for the dub's mix.
    static func tone(duration: TimeInterval, to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let frames = AVAudioFrameCount(duration * 44_100)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for index in 0..<Int(frames) {
            let t = Double(index) / 44_100
            samples[index] = Float(0.15 * sin(2 * .pi * 220 * t) + 0.08 * sin(2 * .pi * 330 * t))
        }
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1
        ])
        try file.write(from: buffer)
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw DubExportError.renderSetupFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw DubExportError.renderSetupFailed }
    }

    /// Draws `duration * fps` frames with `draw` (Core Graphics, bottom-left origin) into an
    /// H.264 file.
    static func write(
        size: CGSize,
        duration: TimeInterval,
        fps: Int32,
        to url: URL,
        draw: (CGContext, TimeInterval) -> Void
    ) async throws {
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: url.pathExtension == "mov" ? .mov : .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<max(1, Int(duration * Double(fps))) {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &buffer)
            guard let pixelBuffer = buffer else { throw DubExportError.renderSetupFailed }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let context = CGContext(
                data: CVPixelBufferGetBaseAddress(pixelBuffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) {
                draw(context, Double(frame) / Double(fps))
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps)) else {
                throw DubExportError.writerFailed(writer.error)
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw DubExportError.writerFailed(writer.error) }
    }
}
