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

    /// Whole-scene playback must wait for the same future host-time deadline as the audio
    /// nodes. This is the regression for fast video starting immediately while audio still
    /// sat in its scheduling lead-in, followed by a stream of corrective seeks.
    @Test func wholeSceneStartsOnTheSharedAudioAnchor() async throws {
        let (picture, directory) = try makePicture()
        defer { try? FileManager.default.removeItem(at: directory) }

        let ready = try await waitUntil { picture.isReadyForTesting }
        #expect(ready, "video did not become ready")

        let offset: TimeInterval = 2
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 1.0)
        picture.playScene(at: DubPlaybackAnchor(offset: offset, hostTime: hostTime))

        // AVPlayer applies the requested item time asynchronously, even though its rate stays
        // stopped until the host deadline. Wait for that harmless positioning jump before
        // measuring whether frames themselves are advancing.
        let positioned = try await waitUntil(timeout: 0.5) {
            picture.currentTimeForTesting >= offset - 0.05
        }
        #expect(positioned, "picture did not position on the requested frame")

        let firstBeforeDeadline = picture.currentTimeForTesting
        try await Task.sleep(for: .milliseconds(200))
        let lastBeforeDeadline = picture.currentTimeForTesting
        #expect(abs(lastBeforeDeadline - firstBeforeDeadline) < 0.08,
                "picture ran before the shared deadline: \(firstBeforeDeadline) → \(lastBeforeDeadline)")

        let advanced = try await waitUntil(timeout: 2) {
            picture.currentTimeForTesting > lastBeforeDeadline + 0.2
        }
        #expect(advanced, "picture did not roll after the shared deadline")
    }

    /// Recording uses the same host-clock technique, but starts at the selected line rather
    /// than at a whole-scene offset. This is the capture-side regression: the video must not
    /// roll during the microphone's scheduling runway.
    @Test func recordedLineStartsOnTheMicrophoneAnchor() async throws {
        let (picture, directory) = try makePicture()
        defer { try? FileManager.default.removeItem(at: directory) }

        let ready = try await waitUntil { picture.isReadyForTesting }
        #expect(ready, "video did not become ready")

        let line = self.line(start: 2, duration: 2)
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.8)
        picture.play(line, at: DubPlaybackAnchor(offset: line.startTime, hostTime: hostTime))

        let positioned = try await waitUntil(timeout: 0.5) {
            picture.currentTimeForTesting >= line.startTime - 0.05
        }
        #expect(positioned, "picture did not position on the line")

        let before = picture.currentTimeForTesting
        try await Task.sleep(for: .milliseconds(200))
        #expect(abs(picture.currentTimeForTesting - before) < 0.08,
                "record picture ran before microphone sample zero")

        let advanced = try await waitUntil(timeout: 2) {
            picture.currentTimeForTesting > before + 0.2
        }
        #expect(advanced, "record picture did not roll after microphone sample zero")
    }

    /// Opening a large imported scene can outlast the audio lead-in. The pending start must
    /// survive that load and join the audio at its then-current timeline position.
    @Test func wholeSceneStartWaitsForVideoReadiness() async throws {
        let (picture, directory) = try makePicture()
        defer { try? FileManager.default.removeItem(at: directory) }

        let offset: TimeInterval = 1
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.1)
        picture.playScene(at: DubPlaybackAnchor(offset: offset, hostTime: hostTime))

        let advanced = try await waitUntil(timeout: 4) {
            picture.currentTimeForTesting > offset + 0.2
        }
        #expect(advanced, "pending picture did not join the running audio timeline")
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
