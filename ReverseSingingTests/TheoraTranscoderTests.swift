//
//  TheoraTranscoderTests.swift
//  ReverseSingingTests
//
//  The scene video coming out the same length, and the same shape, as it went in
//

import Testing
import Foundation
import AVFoundation
import CoreGraphics
@testable import ReverseSinging

private final class TranscoderBundleToken {}

@Suite("Theora Transcoder")
struct TheoraTranscoderTests {

    // MARK: - Helpers

    private func fixture(_ name: String) throws -> URL {
        let bundle = Bundle(for: TranscoderBundleToken.self)
        return try #require(bundle.url(forResource: name, withExtension: "ogv"))
    }

    private func workingDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("theora-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Mean luma of the frame shown at `time`, 0...255.
    ///
    /// The fixture paints each three-second segment a flat, distinct grey, so this is enough
    /// to say *which part of the source* is on screen at a given moment — which is the only
    /// question that matters for sync.
    private func meanLuma(of video: URL, at time: TimeInterval) async throws -> Double {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let cgImage = try await generator.image(
            at: CMTime(seconds: time, preferredTimescale: 600)
        ).image

        let width = 32, height = 32
        // Allocated rather than a Swift array: `CGContext` keeps the pointer it is handed,
        // and an array's storage is only guaranteed for the duration of the `&` call.
        let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
        pixels.initialize(repeating: 0, count: width * height)
        defer { pixels.deallocate() }

        let context = try #require(CGContext(
            data: pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        for index in 0..<(width * height) { total += Double(pixels[index]) }
        return total / Double(width * height)
    }

    // MARK: - Length

    /// The regression this suite exists for.
    ///
    /// `test_dup.ogv` is 9 seconds of 15 fps in which 101 of the 135 frames are duplicates —
    /// the shape of a film scene padded up to a higher frame rate, and of the real packs that
    /// played out of sync. A transcoder that treats `TH_DUPFRAME` as a decode failure writes
    /// only the 34 frames it considers new, and hands back a 2.3-second video for a 9-second
    /// scene: the picture then races the voices, further ahead with every duplicate.
    @Test("A scene full of duplicate frames keeps its full length")
    func duplicateFramesAreNotDropped() throws {
        let directory = try workingDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("out.mp4")
        let written = try TheoraTranscoder.transcode(ogv: try fixture("test_dup"), to: destination)

        #expect(written.frameCount == 135, "every frame belongs on the timeline, duplicates included")
        #expect(abs(written.duration - 9.0) < 0.001)

        let onDisk = CMTimeGetSeconds(AVURLAsset(url: destination).duration)
        #expect(abs(onDisk - 9.0) < 0.07, "wrote \(onDisk)s for a 9s source")
    }

    /// A file with nothing to repeat must come out exactly as it did before, or the fix for
    /// duplicates has been paid for by breaking everything else.
    @Test("A scene with no duplicate frames is unchanged")
    func plainSceneIsUnchanged() throws {
        let directory = try workingDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("out.mp4")
        let written = try TheoraTranscoder.transcode(ogv: try fixture("test"), to: destination)

        #expect(written.frameCount == 135)
        #expect(abs(written.duration - 9.0) < 0.001)
    }

    /// A real pack's `dub_video.ogv` carries a Vorbis track alongside the Theora video, and
    /// the single-stream fixtures cannot catch a demuxer that mishandles the second stream.
    @Test("A scene carrying a Vorbis track converts whole")
    func audioVideoSceneKeepsItsLength() async throws {
        let directory = try workingDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("out.mp4")
        let written = try TheoraTranscoder.transcode(ogv: try fixture("test_av"), to: destination)

        #expect(written.frameCount == 135)
        #expect(abs(written.duration - 9.0) < 0.001)

        let asset = AVURLAsset(url: destination)
        let duration = try await asset.load(.duration).seconds
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)

        #expect(abs(duration - 9.0) < 0.07, "duration was \(duration)")
        #expect(Int(size.width) == 640)
        #expect(Int(size.height) == 480)
    }

    // MARK: - Placement

    /// Length alone would pass a file that is the right duration with the wrong frames in it.
    ///
    /// The fixture's three segments are flat greys of 80, 110 and 140, one per three seconds,
    /// so what is on screen at a given second says exactly where the source has been placed.
    @Test("Every second of the source lands on the same second of the output")
    func framesLandWhereTheyBelong() async throws {
        let directory = try workingDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("out.mp4")
        try TheoraTranscoder.transcode(ogv: try fixture("test_dup"), to: destination)

        // Measured from the fixture rather than derived from the greys it is painted with:
        // the sliding marker and the corner blocks lift the mean, and the trip through
        // Y'CbCr and back moves it again. The three are ~35 apart, so the tolerance below
        // still cannot confuse one segment for another.
        let expected: [(time: TimeInterval, luma: Double)] = [
            (1.0, 90.7), (4.0, 123.3), (7.0, 166.8),
        ]

        // Sampled inside each segment rather than on a boundary, so a frame either side
        // cannot decide the result.
        for sample in expected {
            let measured = try await meanLuma(of: destination, at: sample.time)
            #expect(
                abs(measured - sample.luma) < 15,
                "at \(sample.time)s the picture reads \(Int(measured)), expected ~\(Int(sample.luma))"
            )
        }
    }
}
