//
//  DubBoothCompositingTests.swift
//  ReverseSingingTests
//
//  The booth lands where the layout says it does
//

import Testing
import Foundation
import AVFoundation
import CoreImage
@testable import ReverseSinging

// MARK: - Layout

/// Pure geometry, checked without touching AVFoundation.
@Suite("Booth Layout")
struct DubBoothLayoutTests {

    private let scene = CGSize(width: 1280, height: 720)
    private let booth = CGSize(width: 720, height: 1280)

    @Test func offKeepsTheSceneAloneAtItsOwnSize() {
        let layout = DubBoothLayout.make(frame: .off, sceneDisplaySize: scene, boothDisplaySize: booth)

        #expect(layout.renderSize == scene)
        #expect(layout.boothRect == nil)
    }

    /// The inset takes the booth's own aspect so filling it is exact. If it ever stopped
    /// matching, the booth would spill over the picture with nothing drawn after to hide it.
    @Test func theCornerInsetMatchesTheBoothAspectExactly() throws {
        let layout = DubBoothLayout.make(frame: .corner, sceneDisplaySize: scene, boothDisplaySize: booth)

        let rect = try #require(layout.boothRect)
        let insetAspect = rect.width / rect.height
        let boothAspect = booth.width / booth.height

        #expect(abs(insetAspect - boothAspect) < 0.01)
        #expect(layout.boothIsOnTop, "the inset has to sit over the picture")
        #expect(layout.renderSize == scene, "a corner inset must not change the output shape")
    }

    /// The check that a pure aspect-ratio test misses: an inset can match the booth exactly
    /// and still be most of the picture. Sized by the frame's width, this one came out 70%
    /// of its height.
    @Test func theCornerInsetIsAnInsetRatherThanASecondPicture() throws {
        let layout = DubBoothLayout.make(frame: .corner, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)

        #expect(rect.height / scene.height < 0.4, "an inset taller than 40% of the frame is not an inset")
        #expect(rect.width / scene.width < 0.25)
        #expect(rect.height / scene.height > 0.2, "and one too small to read a face in is no use either")
    }

    @Test func theCornerInsetSitsInsideTheFrame() throws {
        let layout = DubBoothLayout.make(frame: .corner, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)

        #expect(rect.minX > 0)
        #expect(rect.minY > 0)
        #expect(rect.maxX < scene.width)
        #expect(rect.maxY < scene.height)
    }

    /// 9:16, scene on top, and the three bands meet with no gap and no overlap.
    @Test func stackedRendersPortraitWithTheSceneOnTop() throws {
        let layout = DubBoothLayout.make(frame: .stacked, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)
        let wave = try #require(layout.waveRect)

        #expect(layout.renderSize == CGSize(width: 1080, height: 1920))
        #expect(layout.sceneRect.minY == 0)
        #expect(rect.minY == layout.sceneRect.maxY, "the bands must meet exactly")
        #expect(rect.maxY == wave.minY, "the booth runs down to the waveform and no further")
        #expect(wave.maxY == layout.renderSize.height)
        #expect(
            !layout.boothIsOnTop,
            "the booth overflows its band upward, so the scene has to be drawn after it"
        )
    }

    /// The mirror of `stacked`: the face goes on top, the film underneath.
    @Test func reactionPutsTheBoothAboveTheScene() throws {
        let layout = DubBoothLayout.make(frame: .reaction, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)
        let wave = try #require(layout.waveRect)

        #expect(layout.renderSize == CGSize(width: 1080, height: 1920))
        #expect(rect.minY == 0, "the booth starts at the top of the frame")
        #expect(rect.maxY == layout.sceneRect.minY, "the bands must meet exactly")
        #expect(layout.sceneRect.maxY == wave.minY)
        #expect(
            !layout.boothIsOnTop,
            "the booth overflows downward into the scene, so the scene is drawn after it"
        )
    }

    /// The two vertical frames use exactly the same bands, in the other order.
    @Test func theVerticalFramesAreOneAnothersMirror() throws {
        let stacked = DubBoothLayout.make(frame: .stacked, sceneDisplaySize: scene, boothDisplaySize: booth)
        let reaction = DubBoothLayout.make(frame: .reaction, sceneDisplaySize: scene, boothDisplaySize: booth)

        #expect(stacked.renderSize == reaction.renderSize)
        #expect(stacked.waveRect == reaction.waveRect)
        #expect(stacked.sceneRect.size == reaction.sceneRect.size)
        #expect(try #require(stacked.boothRect).size == (try #require(reaction.boothRect)).size)
        #expect(stacked.sceneRectAlone == reaction.sceneRectAlone,
                "with nobody in the booth the two frames are the same picture")
    }

    /// The fix for the band of black that a scene with gaps used to export.
    @Test func aVerticalFrameGivesTheBoothBandBackWhenThereIsNoFootageForIt() throws {
        for frame in [DubBoothFrame.stacked, .reaction] {
            let layout = DubBoothLayout.make(frame: frame, sceneDisplaySize: scene, boothDisplaySize: booth)
            let wave = try #require(layout.waveRect)

            #expect(layout.sceneRectAlone.size == layout.sceneRect.size,
                    "the scene moves rather than resizing, so each line reads as a cut")
            #expect(
                abs(layout.sceneRectAlone.midY - wave.minY / 2) < 1,
                "the scene is centred in the picture area, so what black is left is symmetrical"
            )
            #expect(layout.sceneRectAlone.minY > 0, "and it is no longer pinned to an edge")
        }
    }

    /// The same gap, in the landscape frame that has one.
    @Test func splitGivesTheWholeFrameBackWhenTheBoothIsNotRolling() {
        let layout = DubBoothLayout.make(frame: .split, sceneDisplaySize: scene, boothDisplaySize: booth)

        #expect(layout.sceneRectAlone == CGRect(origin: .zero, size: layout.renderSize))
    }

    /// A pack that is already portrait leaves no room for a face, and is not cropped to make
    /// some. It still gets the vertical canvas and the waveform.
    @Test func aPortraitPackKeepsItsPictureRatherThanMakingRoomForTheBooth() {
        let layout = DubBoothLayout.make(
            frame: .stacked,
            sceneDisplaySize: CGSize(width: 1080, height: 1920),
            boothDisplaySize: booth
        )

        #expect(layout.boothRect == nil)
        #expect(layout.waveRect != nil)
        #expect(layout.sceneRect == layout.sceneRectAlone)
    }

    /// Only the frames that stand up on their own are worth rendering with no booth in them.
    @Test func onlyTheVerticalFramesAreVerticalOnes() {
        #expect(DubBoothFrame.stacked.isVertical)
        #expect(DubBoothFrame.reaction.isVertical)
        #expect(!DubBoothFrame.off.isVertical)
        #expect(!DubBoothFrame.corner.isVertical)
        #expect(!DubBoothFrame.split.isVertical)
    }

    /// Only the vertical frames carry a strip; the rest are the shapes they always were.
    @Test func onlyTheVerticalFramesReserveAWaveformStrip() {
        for frame in DubBoothFrame.allCases {
            let layout = DubBoothLayout.make(frame: frame, sceneDisplaySize: scene, boothDisplaySize: booth)
            #expect((layout.waveRect != nil) == frame.isVertical, "\(frame)")
        }
    }

    @Test func splitGivesEachHalfTheFullHeight() throws {
        let layout = DubBoothLayout.make(frame: .split, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)

        #expect(layout.sceneRect.width + rect.width == scene.width)
        #expect(layout.sceneRect.height == scene.height)
        #expect(rect.height == scene.height)
        #expect(rect.minX == layout.sceneRect.maxX)
        #expect(layout.boothIsOnTop, "the scene overflows right, so the booth has to cover it")
    }

    /// A zero anywhere would divide by it. Packs whose video failed to load have arrived here.
    @Test func aDegenerateSourceFallsBackRatherThanDividingByZero() {
        let layout = DubBoothLayout.make(
            frame: .stacked,
            sceneDisplaySize: .zero,
            boothDisplaySize: .zero
        )
        #expect(layout.renderSize.width > 0)
        #expect(layout.renderSize.height > 0)
    }

    /// H.264 refuses odd dimensions.
    @Test func renderSizesAreAlwaysEven() {
        let layout = DubBoothLayout.make(
            frame: .corner,
            sceneDisplaySize: CGSize(width: 1281, height: 721),
            boothDisplaySize: booth
        )
        #expect(Int(layout.renderSize.width) % 2 == 0)
        #expect(Int(layout.renderSize.height) % 2 == 0)
    }

    @Test func fillingARectCoversItEntirely() {
        let rect = CGRect(x: 100, y: 50, width: 400, height: 300)
        let transform = DubBoothLayout.fillTransform(displaySize: booth, into: rect)
        let covered = CGRect(origin: .zero, size: booth).applying(transform)

        #expect(covered.minX <= rect.minX + 0.5)
        #expect(covered.minY <= rect.minY + 0.5)
        #expect(covered.maxX >= rect.maxX - 0.5)
        #expect(covered.maxY >= rect.maxY - 0.5)
    }
}

// MARK: - Cut Planning

@Suite("Dub Cut Planning")
struct DubCutPlannerTests {

    private func makePack(lineCount: Int, lineDuration: TimeInterval = 2, gap: TimeInterval = 3) -> DubPack {
        let lines = (0..<lineCount).map { index in
            DubLine(
                index: index + 1,
                slug: String(format: "%03d_Tester", index + 1),
                character: "Tester",
                caption: "line \(index + 1)",
                imageFile: "x.jpg",
                referenceAudioFile: "x.wav",
                startTime: Double(index) * gap,
                duration: lineDuration
            )
        }
        return DubPack(
            title: "Cuts",
            authors: [],
            iconFile: "x.jpg",
            backingTrackFile: nil,
            folderName: "cuts",
            lines: lines,
            duration: Double(lineCount) * gap
        )
    }

    @Test func theFullSceneIsOneSegmentCoveringEverything() {
        let pack = makePack(lineCount: 3)
        let segments = DubCutPlanner.segments(for: .fullScene, pack: pack, recordedSlugs: [])

        #expect(segments.count == 1)
        #expect(segments[0].start == 0)
        #expect(segments[0].duration == pack.duration)
    }

    @Test func aSingleLineIsJustThatLine() {
        let pack = makePack(lineCount: 3)
        let slug = pack.lines[1].slug
        let segments = DubCutPlanner.segments(for: .line(slug), pack: pack, recordedSlugs: [slug])

        #expect(segments.count == 1)
        #expect(segments[0].start == pack.lines[1].startTime)
        #expect(segments[0].duration == pack.lines[1].duration)
        #expect(segments[0].slug == slug)
    }

    /// The point of the reel: the silence between lines is dropped, so it runs to the sum of
    /// the lines rather than the length of the scene.
    @Test func theSessionReelDropsTheGapsBetweenLines() {
        let pack = makePack(lineCount: 3, lineDuration: 2, gap: 10)
        let recorded = Set(pack.lines.map(\.slug))
        let segments = DubCutPlanner.segments(for: .sessionReel, pack: pack, recordedSlugs: recorded)

        #expect(segments.count == 3)
        #expect(segments.reduce(0) { $0 + $1.duration } == 6)
        #expect(pack.duration == 30, "the scene itself is far longer than its reel")
    }

    @Test func theSessionReelSkipsLinesThatWereNeverDubbed() {
        let pack = makePack(lineCount: 4)
        let recorded: Set<String> = [pack.lines[0].slug, pack.lines[2].slug]
        let segments = DubCutPlanner.segments(for: .sessionReel, pack: pack, recordedSlugs: recorded)

        #expect(segments.map(\.slug) == [pack.lines[0].slug, pack.lines[2].slug])
    }

    /// Recording order is scene order. A reel that jumped about would read as broken.
    @Test func theSessionReelStaysInSceneOrder() {
        let pack = makePack(lineCount: 4)
        let recorded = Set(pack.lines.map(\.slug))
        let segments = DubCutPlanner.segments(for: .sessionReel, pack: pack, recordedSlugs: recorded)

        #expect(segments.map(\.start) == segments.map(\.start).sorted())
    }

    /// A manifest whose last line runs past the end of the film has arrived in the wild.
    @Test func aLineRunningPastTheEndOfTheSceneIsClamped() {
        var pack = makePack(lineCount: 1, lineDuration: 100, gap: 0)
        pack = DubPack(
            id: pack.id,
            title: pack.title,
            authors: pack.authors,
            iconFile: pack.iconFile,
            backingTrackFile: nil,
            folderName: pack.folderName,
            lines: pack.lines,
            duration: 5
        )
        let segments = DubCutPlanner.segments(
            for: .line(pack.lines[0].slug),
            pack: pack,
            recordedSlugs: [pack.lines[0].slug]
        )

        #expect(segments[0].duration == 5)
    }

    @Test func anUnknownSlugProducesNothingRatherThanTheWholeScene() {
        let pack = makePack(lineCount: 2)
        #expect(DubCutPlanner.segments(for: .line("nope"), pack: pack, recordedSlugs: []).isEmpty)
    }
}

// MARK: - Coverage

@Suite("Booth Instruction Coverage")
struct DubBoothCoverageTests {

    private func range(_ start: Double, _ duration: Double) -> CMTimeRange {
        CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
    }

    /// Instructions must tile the whole film with no gap: an uncovered stretch renders nothing.
    @Test func instructionsTileTheWholeDuration() {
        let total = CMTime(seconds: 10, preferredTimescale: 600)
        let ranges = DubBoothComposer.coverage(of: [range(2, 1), range(6, 2)], within: total)

        #expect(ranges.first?.range.start == .zero)
        #expect(CMTimeCompare(ranges.last!.range.end, total) == 0)

        for (previous, next) in zip(ranges, ranges.dropFirst()) {
            #expect(CMTimeCompare(previous.range.end, next.range.start) == 0, "no gaps between instructions")
        }
    }

    @Test func theBoothIsMarkedOnlyWhereItWasInserted() {
        let total = CMTime(seconds: 10, preferredTimescale: 600)
        let ranges = DubBoothComposer.coverage(of: [range(2, 1)], within: total)

        #expect(ranges.count == 3)
        #expect(ranges.map(\.hasBooth) == [false, true, false])
    }

    /// Overlapping instructions are rejected outright by AVFoundation, and lines in a manifest
    /// can genuinely overlap.
    @Test func overlappingBoothClipsAreMergedIntoOneRange() {
        let total = CMTime(seconds: 10, preferredTimescale: 600)
        let ranges = DubBoothComposer.coverage(of: [range(1, 3), range(2, 3)], within: total)

        #expect(ranges.map(\.hasBooth) == [false, true, false])
        #expect(ranges[1].range.start.seconds == 1)
        #expect(ranges[1].range.end.seconds == 5)
    }

    /// A film with no booth in it at all still needs one instruction, or it renders black.
    @Test func nothingToCompositeStillProducesAnInstruction() {
        let total = CMTime(seconds: 4, preferredTimescale: 600)
        let ranges = DubBoothComposer.coverage(of: [], within: total)

        #expect(ranges.count == 1)
        #expect(ranges[0].hasBooth == false)
        #expect(CMTimeCompare(ranges[0].range.duration, total) == 0)
    }
}

// MARK: - Rendered Output

/// Renders real compositions and reads the pixels back.
///
/// The layout arithmetic is checked above, but two things it depends on are AVFoundation's to
/// decide and not documented in a way worth trusting: which end of `layerInstructions` is the
/// front-most layer, and whether the render space has its origin at the top or the bottom.
/// Both are invisible in code review and obvious in a frame, so this renders a red scene and a
/// blue booth and looks at where each one ended up.
@Suite("Booth Compositing Output", .serialized)
struct DubBoothCompositingOutputTests {

    private enum Dominant { case red, blue, other }

    // MARK: Fixtures

    /// A solid-colour H.264 clip, which is all the geometry needs to be readable.
    private func writeClip(
        size: CGSize,
        duration: TimeInterval,
        red: Bool,
        to url: URL
    ) async throws {
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height)
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &buffer
        )
        let pixelBuffer = try #require(buffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
            for y in 0..<Int(size.height) {
                for x in 0..<Int(size.width) {
                    let offset = y * stride + x * 4
                    // BGRA
                    bytes[offset] = red ? 0 : 255
                    bytes[offset + 1] = 0
                    bytes[offset + 2] = red ? 255 : 0
                    bytes[offset + 3] = 255
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let frameRate: Int32 = 10
        for frame in 0..<Int(duration * Double(frameRate)) {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            adaptor.append(
                pixelBuffer,
                withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)
            )
        }

        input.markAsFinished()
        await writer.finishWriting()
    }

    private func makePack(lineDuration: TimeInterval) -> (DubPack, DubLine) {
        let line = DubLine(
            index: 1,
            slug: "001_Tester",
            character: "Tester",
            caption: "line",
            imageFile: "x.jpg",
            referenceAudioFile: "x.wav",
            startTime: 0,
            duration: lineDuration
        )
        let pack = DubPack(
            title: "Booth Geometry",
            authors: [],
            iconFile: "x.jpg",
            backingTrackFile: nil,
            folderName: "booth-geometry",
            lines: [line],
            duration: lineDuration
        )
        return (pack, line)
    }

    // MARK: Rendering

    /// Composes, exports and hands back a frame from the middle of the result.
    private func render(
        frame: DubBoothFrame,
        includesBooth: Bool = true
    ) async throws -> (image: CGImage, size: CGSize) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("booth-geometry-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let duration: TimeInterval = 1.0
        let sceneURL = directory.appendingPathComponent("scene.mp4")
        let boothURL = directory.appendingPathComponent("booth.mp4")

        try await writeClip(size: CGSize(width: 640, height: 360), duration: duration, red: true, to: sceneURL)
        try await writeClip(size: CGSize(width: 360, height: 640), duration: duration, red: false, to: boothURL)

        let (pack, line) = makePack(lineDuration: duration)

        let composed = try await DubBoothComposer.compose(
            pack: pack,
            segments: DubCutPlanner.segments(
                for: .fullScene,
                pack: pack,
                recordedSlugs: [line.slug]
            ),
            frame: frame,
            includesBooth: includesBooth,
            sceneVideo: sceneURL,
            // The composer takes whatever audio track this asset has, which is none. The
            // geometry does not care, and a silent fixture keeps the test to one concern.
            audio: sceneURL,
            boothClips: [line.slug: boothURL]
        )

        let videoComposition = try #require(
            composed.videoComposition,
            "a booth frame has to produce a video composition, or nothing is composited"
        )

        let generator = AVAssetImageGenerator(asset: composed.composition)
        generator.videoComposition = videoComposition
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let image = try generator.copyCGImage(
            at: CMTime(seconds: duration / 2, preferredTimescale: 600),
            actualTime: nil
        )
        return (image, videoComposition.renderSize)
    }

    /// Which of the two fixture colours is at a point, in top-left origin coordinates.
    private func dominant(at point: CGPoint, in image: CGImage) -> Dominant {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .other }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let x = min(max(Int(point.x), 0), width - 1)
        let y = min(max(Int(point.y), 0), height - 1)
        let offset = y * width * 4 + x * 4

        let r = Int(pixels[offset])
        let b = Int(pixels[offset + 2])

        // H.264 goes through YUV, so the values shift. The question is only which channel won.
        if r > b + 40 { return .red }
        if b > r + 40 { return .blue }
        return .other
    }

    // MARK: Tests

    /// The scene keeps the frame and the booth sits over its bottom-right corner.
    @Test func theCornerInsetLandsOverTheBottomRightOfThePicture() async throws {
        let (image, size) = try await render(frame: .corner)

        #expect(size == CGSize(width: 640, height: 360), "a corner inset must not reshape the output")

        let layout = DubBoothLayout.make(
            frame: .corner,
            sceneDisplaySize: CGSize(width: 640, height: 360),
            boothDisplaySize: CGSize(width: 360, height: 640)
        )
        let inset = try #require(layout.boothRect)

        #expect(dominant(at: CGPoint(x: size.width / 2, y: size.height / 2), in: image) == .red,
                "the middle of the frame is the scene")
        #expect(dominant(at: CGPoint(x: inset.midX, y: inset.midY), in: image) == .blue,
                "the inset is the booth")
        #expect(dominant(at: CGPoint(x: 20, y: 20), in: image) == .red,
                "the opposite corner is still the scene")
    }

    /// Scene above, booth below, in a portrait frame.
    @Test func stackedPutsTheSceneAboveTheBooth() async throws {
        let (image, size) = try await render(frame: .stacked)

        #expect(size == CGSize(width: 1080, height: 1920))

        let layout = DubBoothLayout.make(
            frame: .stacked,
            sceneDisplaySize: CGSize(width: 640, height: 360),
            boothDisplaySize: CGSize(width: 360, height: 640)
        )
        let boothBand = try #require(layout.boothRect)

        #expect(dominant(at: CGPoint(x: size.width / 2, y: layout.sceneRect.midY), in: image) == .red,
                "the top band is the scene")
        #expect(dominant(at: CGPoint(x: size.width / 2, y: boothBand.midY), in: image) == .blue,
                "the bottom band is the booth")
        #expect(dominant(at: CGPoint(x: size.width / 2, y: size.height - 30), in: image) == .blue,
                "the booth reaches the bottom of the frame")
    }

    /// Booth above, scene below, in the same portrait frame.
    @Test func reactionPutsTheBoothAboveTheScene() async throws {
        let (image, size) = try await render(frame: .reaction)

        #expect(size == CGSize(width: 1080, height: 1920))

        let layout = DubBoothLayout.make(
            frame: .reaction,
            sceneDisplaySize: CGSize(width: 640, height: 360),
            boothDisplaySize: CGSize(width: 360, height: 640)
        )
        let boothBand = try #require(layout.boothRect)

        #expect(dominant(at: CGPoint(x: size.width / 2, y: boothBand.midY), in: image) == .blue,
                "the top band is the booth")
        #expect(dominant(at: CGPoint(x: size.width / 2, y: layout.sceneRect.midY), in: image) == .red,
                "the bottom band is the scene")
    }

    /// A vertical frame with the booth switched off is still a 9:16 render, and the picture
    /// sits in the middle of it rather than clinging to one edge with black under it.
    @Test func aVerticalFrameWithoutTheBoothCentresTheSceneAndKeepsTheShape() async throws {
        let (image, size) = try await render(frame: .stacked, includesBooth: false)

        #expect(size == CGSize(width: 1080, height: 1920), "the vertical canvas survives")

        let layout = DubBoothLayout.make(
            frame: .stacked,
            sceneDisplaySize: CGSize(width: 640, height: 360),
            boothDisplaySize: CGSize(width: 360, height: 640)
        )

        #expect(dominant(at: CGPoint(x: size.width / 2, y: layout.sceneRectAlone.midY), in: image) == .red,
                "the scene is where the layout says it moved to")
        #expect(dominant(at: CGPoint(x: size.width / 2, y: layout.boothRect!.midY), in: image) != .blue,
                "and nobody is in the band it used to keep for the booth")
    }

    /// The strip goes into the frame, in the band the layout reserved for it.
    @Test func aVerticalExportCarriesItsWaveformStrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("booth-strip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let duration: TimeInterval = 1.0
        let sceneURL = directory.appendingPathComponent("scene.mp4")
        let boothURL = directory.appendingPathComponent("booth.mp4")
        let waveURL = directory.appendingPathComponent("wave.mp4")

        try await writeClip(size: CGSize(width: 640, height: 360), duration: duration, red: true, to: sceneURL)
        try await writeClip(size: CGSize(width: 360, height: 640), duration: duration, red: false, to: boothURL)

        let layout = DubBoothLayout.make(
            frame: .stacked,
            sceneDisplaySize: CGSize(width: 640, height: 360),
            boothDisplaySize: CGSize(width: 360, height: 640)
        )
        let band = try #require(layout.waveRect)

        try await DubWaveOverlay.renderStrip(
            // Every bar at full height, so the strip is unambiguous wherever it is sampled.
            bars: DubWaveOverlay.Bars(
                reference: Array(repeating: 1, count: 160),
                take: Array(repeating: 1, count: 160)
            ),
            labels: ("Original", "My Dub"),
            size: band.size,
            duration: duration,
            to: waveURL
        )

        let (pack, line) = makePack(lineDuration: duration)

        let composed = try await DubBoothComposer.compose(
            pack: pack,
            segments: DubCutPlanner.segments(for: .fullScene, pack: pack, recordedSlugs: [line.slug]),
            frame: .stacked,
            sceneVideo: sceneURL,
            audio: sceneURL,
            boothClips: [line.slug: boothURL],
            waveVideo: waveURL
        )

        let videoComposition = try #require(composed.videoComposition)
        let generator = AVAssetImageGenerator(asset: composed.composition)
        generator.videoComposition = videoComposition
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let image = try generator.copyCGImage(
            at: CMTime(seconds: duration / 2, preferredTimescale: 600),
            actualTime: nil
        )

        // The waveform's own grey is far brighter than the panel it sits on, and brighter than
        // the black an empty band would leave.
        #expect(
            brightest(in: band, of: image) > 120,
            "the strip is missing: the band reserved for it is empty"
        )
        #expect(
            dominant(at: CGPoint(x: band.midX, y: band.midY - band.height / 3), in: image) != .blue,
            "and the booth no longer spills into it"
        )
    }

    /// The brightest channel value anywhere in a band of the frame, top-left origin.
    private func brightest(in rect: CGRect, of image: CGImage) -> Int {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var peak = 0
        for y in stride(from: max(0, Int(rect.minY)), to: min(height, Int(rect.maxY)), by: 4) {
            for x in stride(from: max(0, Int(rect.minX)), to: min(width, Int(rect.maxX)), by: 4) {
                let offset = y * width * 4 + x * 4
                peak = max(peak, Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
            }
        }
        return peak
    }

    /// Two halves, scene on the left.
    @Test func splitPutsTheSceneLeftAndTheBoothRight() async throws {
        let (image, size) = try await render(frame: .split)

        #expect(size == CGSize(width: 640, height: 360))
        #expect(dominant(at: CGPoint(x: size.width * 0.25, y: size.height / 2), in: image) == .red)
        #expect(dominant(at: CGPoint(x: size.width * 0.75, y: size.height / 2), in: image) == .blue)
        #expect(dominant(at: CGPoint(x: size.width * 0.75, y: 20), in: image) == .blue,
                "the booth fills its half top to bottom")
    }

    /// The whole point of keeping `.off` on the remux path: no composition, no re-encode.
    @Test func offProducesNoVideoCompositionAtAll() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("booth-off-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sceneURL = directory.appendingPathComponent("scene.mp4")
        let boothURL = directory.appendingPathComponent("booth.mp4")
        try await writeClip(size: CGSize(width: 640, height: 360), duration: 1, red: true, to: sceneURL)
        try await writeClip(size: CGSize(width: 360, height: 640), duration: 1, red: false, to: boothURL)

        let (pack, line) = makePack(lineDuration: 1)

        let composed = try await DubBoothComposer.compose(
            pack: pack,
            segments: DubCutPlanner.segments(for: .fullScene, pack: pack, recordedSlugs: [line.slug]),
            frame: .off,
            sceneVideo: sceneURL,
            audio: sceneURL,
            boothClips: [line.slug: boothURL]
        )

        #expect(composed.videoComposition == nil,
                "an export with the booth off must stay a passthrough remux")
    }
}
