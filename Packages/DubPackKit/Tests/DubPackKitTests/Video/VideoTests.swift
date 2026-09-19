//
//  VideoTests.swift
//  DubPackKitTests
//
//  The scene video coming out the same length, and the same shape, as it went in
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import DubPackKit

@Suite("Theora transcoder")
struct TheoraTranscoderTests {

    /// The regression this suite exists for.
    ///
    /// `test_dup.ogv` is nine seconds at 15 fps in which 101 of 135 frames are duplicates, the
    /// shape of a film scene padded to a higher frame rate. A transcoder that treats
    /// `TH_DUPFRAME` as a failure writes 34 frames, a 2.3-second video for a 9-second scene,
    /// and the picture races ahead of the voices.
    @Test func keepsEveryDuplicateFrame() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("out.mp4")

        let written = try TheoraTranscoder.transcode(ogv: Fixtures.url("test_dup.ogv"), to: destination)

        #expect(written.frameCount == 135, "every frame belongs on the timeline, duplicates included")
        #expect(abs(written.duration - 9.0) < 0.001)
        let onDisk = try await AVURLAsset(url: destination).load(.duration).seconds
        #expect(abs(onDisk - 9.0) < 0.07, "wrote \(onDisk)s for a 9s source")
    }

    @Test func leavesASceneWithoutDuplicatesUnchanged() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }

        let written = try TheoraTranscoder.transcode(ogv: Fixtures.url("test.ogv"), to: temp.appending("out.mp4"))

        #expect(written.frameCount == 135)
        #expect(abs(written.duration - 9.0) < 0.001)
    }

    /// A real pack's scene carries a Vorbis track too, which single-stream fixtures cannot catch.
    @Test func convertsASceneCarryingAVorbisTrack() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("out.mp4")

        let written = try TheoraTranscoder.transcode(ogv: Fixtures.url("test_av.ogv"), to: destination)

        #expect(written.frameCount == 135)
        let asset = AVURLAsset(url: destination)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(abs(try await asset.load(.duration).seconds - 9.0) < 0.07)
        #expect(Int(size.width) == 640)
        #expect(Int(size.height) == 480)
    }

    /// Length alone would pass a file with the right duration and the wrong frames in it. The
    /// fixture's three segments are distinct greys, one per three seconds.
    @Test func putsEverySecondOfTheSourceOnTheSameSecondOfTheOutput() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("out.mp4")
        try TheoraTranscoder.transcode(ogv: Fixtures.url("test_dup.ogv"), to: destination)

        // Measured from the fixture: the marker and corner blocks lift the mean, and the trip
        // through Y'CbCr moves it again. The three are ~35 apart, well outside the tolerance.
        for (time, luma) in [(1.0, 90.7), (4.0, 123.3), (7.0, 166.8)] {
            let measured = try await meanLuma(of: destination, at: time)
            #expect(abs(measured - luma) < 15, "at \(time)s the picture reads \(Int(measured)), expected ~\(Int(luma))")
        }
    }

    @Test func refusesAFileWithNoTheoraInIt() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let noise = temp.appending("noise.ogv")
        try Data(count: 4096).write(to: noise)

        #expect(throws: VideoConversionFailure.notTheora) {
            try TheoraTranscoder.transcode(ogv: noise, to: temp.appending("out.mp4"))
        }
    }

    /// Mean luma of the frame shown at `time`, from 0 to 255.
    private func meanLuma(of video: URL, at time: TimeInterval) async throws -> Double {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image

        let side = 32
        // Allocated rather than an array: CGContext keeps the pointer it is handed.
        let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: side * side)
        pixels.initialize(repeating: 0, count: side * side)
        defer { pixels.deallocate() }

        let context = try #require(CGContext(
            data: pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        return (0..<(side * side)).reduce(0.0) { $0 + Double(pixels[$1]) } / Double(side * side)
    }
}

@Suite("Scene video converter")
struct SceneVideoConverterTests {

    @Test func convertsTheoraAndDropsTheOriginal() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.copyFixture("test.ogv", as: "dub_video.ogv")

        let outcome = await SceneVideoConverter.convertIfNeeded(in: pack.directory, probe: AVFoundationMediaProbe())

        #expect(outcome == .converted(file: "dub_video.mp4"))
        #expect(!FileManager.default.fileExists(atPath: pack.directory.appendingPathComponent("dub_video.ogv").path))
        #expect(FileManager.default.fileExists(atPath: pack.directory.appendingPathComponent("dub_video.mp4").path))
    }

    @Test func leavesAPlayableVideoAlone() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.h264Video("dub_video.mp4")

        #expect(await SceneVideoConverter.convertIfNeeded(in: pack.directory, probe: AVFoundationMediaProbe()) == .nothingToConvert)
    }

    /// A short output plays and looks fine while every later line runs early: better stills.
    @Test func throwsAwayAConversionThatCameOutShort() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.copyFixture("test.ogv", as: "dub_video.ogv")

        let probe = StubMediaProbe(videoDurations: ["dub_video.mp4": 3.5])
        let outcome = await SceneVideoConverter.convertIfNeeded(in: pack.directory, probe: probe)

        #expect(outcome == .failed(file: "dub_video.ogv", failure: .lengthMismatch(expected: 9, actual: 3.5)))
        #expect(try FileManager.default.contentsOfDirectory(atPath: pack.directory.path).isEmpty)
    }

    @Test func reportsAVideoThatWillNotDecode() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write(Data(count: 4096), to: "dub_video.ogv")

        let outcome = await SceneVideoConverter.convertIfNeeded(in: pack.directory, probe: AVFoundationMediaProbe())

        #expect(outcome == .failed(file: "dub_video.ogv", failure: .notTheora))
    }
}
