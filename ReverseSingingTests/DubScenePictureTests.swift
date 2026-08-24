//
//  DubScenePictureTests.swift
//  ReverseSingingTests
//
//  The scene video actually rolling — not merely being on screen
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

private final class ScenePictureBundleToken {}

@Suite("Dub Scene Picture")
@MainActor
struct DubScenePictureTests {

    /// A picture pointed at a freshly transcoded copy of the Theora fixture.
    private func makePicture() throws -> (DubScenePicture, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("scenepic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let bundle = Bundle(for: ScenePictureBundleToken.self)
        let source = try #require(bundle.url(forResource: "test", withExtension: "ogv"))
        let video = directory.appendingPathComponent("dub_video.mp4")
        try TheoraTranscoder.transcode(ogv: source, to: video)

        let picture = DubScenePicture()
        picture.configureForTesting(videoURL: video)
        return (picture, directory)
    }

    private func line(start: TimeInterval, duration: TimeInterval) -> DubLine {
        DubLine(
            index: 1, slug: "001_A", character: "A", caption: "c",
            imageFile: "a.jpg", referenceAudioFile: "a.wav",
            startTime: start, duration: duration
        )
    }

    /// Polls rather than sleeping a fixed span: under a full-suite load the player can take
    /// noticeably longer to start, and a fixed wait turns that into a false failure.
    private func waitUntil(
        timeout: TimeInterval = 6,
        _ condition: () -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    @Test func rollsTheVideoWhilePlayingALine() async throws {
        let (picture, directory) = try makePicture()
        defer { try? FileManager.default.removeItem(at: directory) }

        let line = self.line(start: 0, duration: 3)

        picture.show(line)
        _ = try await waitUntil { picture.currentTimeForTesting >= 0 }
        let parked = picture.currentTimeForTesting

        picture.play(line)

        let advanced = try await waitUntil {
            picture.currentTimeForTesting > parked + 0.3
        }

        #expect(advanced,
                "picture should have advanced; parked=\(parked) now=\(picture.currentTimeForTesting)")
    }

    /// A take routinely runs past the line, so the picture has to keep moving. Asserts both
    /// halves: it never stops, and it never runs on past the line into the next shot.
    @Test func loopsTheLineWhileTheMicIsOpen() async throws {
        let (picture, directory) = try makePicture()
        defer { try? FileManager.default.removeItem(at: directory) }

        let line = self.line(start: 0, duration: 0.6)
        picture.play(line, loop: true)

        _ = try await waitUntil { picture.rateForTesting > 0 }

        // Long enough to cover several passes of a 0.6s line.
        var sawRewind = false
        var previous = picture.currentTimeForTesting
        let deadline = Date().addingTimeInterval(4)

        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
            let now = picture.currentTimeForTesting
            if now < previous - 0.1 { sawRewind = true }
            previous = now

            #expect(picture.rateForTesting > 0, "looping must not pause the picture")
            #expect(now < line.endTime + 1.0,
                    "looping must not run past the line; reached \(now)")
        }

        #expect(sawRewind, "expected the picture to jump back to the line's start")
    }

    @Test func stopsAtTheEndOfTheLine() async throws {
        let (picture, directory) = try makePicture()
        defer { try? FileManager.default.removeItem(at: directory) }

        // A short line so the boundary lands well inside the 9s video.
        let line = self.line(start: 0, duration: 0.5)
        picture.play(line)

        // Wait for it to actually start before expecting it to stop, otherwise a slow start
        // is indistinguishable from a stop that never happened.
        _ = try await waitUntil { picture.rateForTesting > 0 || picture.currentTimeForTesting > 0 }

        let paused = try await waitUntil { picture.rateForTesting == 0 }

        #expect(paused, "should have paused at the line's end")
        #expect(picture.currentTimeForTesting < 2,
                "stopped at \(picture.currentTimeForTesting), well past the 0.5s boundary")
    }
}

// MARK: - Multi-stream Ogg

/// A real pack's `dub_video.ogv` carries a Vorbis audio track alongside the Theora video.
/// The single-stream fixture used elsewhere cannot catch a demuxer that mishandles that.
@Suite("Theora Transcoder")
struct TheoraTranscoderTests {

    @Test func convertsAnOggCarryingBothVideoAndAudio() async throws {
        let bundle = Bundle(for: ScenePictureBundleToken.self)
        let source = try #require(bundle.url(forResource: "test_av", withExtension: "ogv"))
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("av-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: output) }

        try TheoraTranscoder.transcode(ogv: source, to: output)

        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)

        #expect(abs(duration - 9.0) < 0.3, "duration was \(duration)")
        #expect(Int(size.width) == 640)
        #expect(Int(size.height) == 480)
    }
}
