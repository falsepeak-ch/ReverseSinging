//
//  DubScenePictureTests.swift
//  ReverseSingingTests
//
//  The scene video actually rolling. Not merely being on screen
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

private final class ScenePictureBundleToken {}

/// Serialized, because the contention these tests are most sensitive to is their own.
///
/// Each one transcodes the Theora fixture and stands up its own `AVPlayer`, and run in
/// parallel that is six simultaneous video pipelines on one simulator. A load the app never
/// creates for itself. Starve them enough and `AVPlayer` does not merely drift, it never
/// starts: under an artificial six-way CPU saturation every failure here read `now = 0.0`,
/// zero rewinds, never paused. No amount of tolerance in an assertion fixes a player that
/// never played, so the fix is to stop making the load.
///
/// The timing assertions inside are still written to survive a busy machine, because CI is
/// one. This only removes the part of the busyness that was self-inflicted.
@Suite("Dub Scene Picture", .serialized)
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
    ///
    /// The ceiling is deliberately far above what a warm run needs. Several of these tests
    /// transcode a fixture and spin up an `AVPlayer` each, and when the whole suite runs at
    /// once they do it simultaneously. The observed starts ranged from tens of milliseconds
    /// to several seconds on the same machine. A timeout tight enough to be "fast" is really
    /// just a bet on machine load.
    private func waitUntil(
        timeout: TimeInterval = 10,
        _ condition: () -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    /// How far the picture moves while a host-clock runway is still open.
    ///
    /// Both anchor tests below assert the same thing. The picture must not roll during the
    /// audio's scheduling lead-in. And both used to do it by sampling, sleeping 200 ms, and
    /// sampling again. That is only a measurement of the runway if both samples land inside
    /// it, and under a full-suite load `Task.sleep` overshoots by hundreds of milliseconds.
    /// When it overshot the deadline the second sample caught a picture that was correctly
    /// rolling, and the test called that a failure. It was the single flakiest assertion here.
    ///
    /// So the runway is set generously by the caller, and every sample is taken only after
    /// the host clock has been checked, which makes each one provably inside it. Returns nil
    /// when too few samples fit to mean anything. Which at these lead-ins means the machine
    /// stalled for seconds, and is worth failing on rather than passing quietly.
    private func drift(beforeHostDeadline deadline: UInt64, of picture: DubScenePicture) async throws -> TimeInterval? {
        var samples: [TimeInterval] = []

        while mach_absolute_time() < deadline {
            samples.append(picture.currentTimeForTesting)
            try await Task.sleep(for: .milliseconds(40))
        }

        guard samples.count >= 3, let low = samples.min(), let high = samples.max() else {
            return nil
        }
        return high - low
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
        // Three seconds of runway: one for the positioning jump to land in, two to sample.
        // The number is not the behaviour under test, it is only how much room the
        // measurement gets, so it is set well clear of how slow a loaded machine can be.
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 3.0)
        picture.playScene(at: DubPlaybackAnchor(offset: offset, hostTime: hostTime))

        // AVPlayer applies the requested item time asynchronously, even though its rate stays
        // stopped until the host deadline. Wait for that harmless positioning jump before
        // measuring whether frames themselves are advancing.
        let positioned = try await waitUntil(timeout: 1) {
            picture.currentTimeForTesting >= offset - 0.05
        }
        #expect(positioned, "picture did not position on the requested frame")

        let sampled = try await drift(beforeHostDeadline: hostTime, of: picture)
        let moved = try #require(sampled, "the runway closed before it could be sampled")
        #expect(moved < 0.08, "picture ran before the shared deadline: moved \(moved)s")

        let parked = picture.currentTimeForTesting
        let advanced = try await waitUntil(timeout: 4) {
            picture.currentTimeForTesting > parked + 0.2
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
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 3.0)
        picture.play(line, at: DubPlaybackAnchor(offset: line.startTime, hostTime: hostTime))

        let positioned = try await waitUntil(timeout: 1) {
            picture.currentTimeForTesting >= line.startTime - 0.05
        }
        #expect(positioned, "picture did not position on the line")

        let sampled = try await drift(beforeHostDeadline: hostTime, of: picture)
        let moved = try #require(sampled, "the microphone runway closed before it could be sampled")
        #expect(moved < 0.08, "record picture ran before microphone sample zero: moved \(moved)s")

        let parked = picture.currentTimeForTesting
        let advanced = try await waitUntil(timeout: 4) {
            picture.currentTimeForTesting > parked + 0.2
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

        // This is the one test that deliberately starts *before* the video is ready, so it
        // waits on a cold player by design. The old 4 s ceiling was the warm case plus a
        // margin, and it lost that bet whenever the rest of the suite was loading players of
        // its own. What is under test is that the pending start survives at all, not how fast.
        let advanced = try await waitUntil(timeout: 12) {
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

        // A rewind is detected against the highest point reached, not against the previous
        // sample. Consecutive samples only catch a wrap if one of them lands in the moment
        // after it, and on a loaded machine a 50 ms sleep can overshoot a whole 0.6 s pass,
        // so every sample lands near the top of the line and the wrap goes unseen. Comparing
        // to the high-water mark catches it from anywhere in the following pass, and resetting
        // the mark on each rewind keeps the count one-per-wrap rather than one-per-sample.
        var highWater = picture.currentTimeForTesting
        var rewinds = 0
        var furthest = highWater

        // Ten passes of a 0.6 s line, so a wrap has to be missed repeatedly to be missed.
        let deadline = Date().addingTimeInterval(6)

        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
            let now = picture.currentTimeForTesting

            if now < highWater - 0.1 {
                rewinds += 1
                highWater = now
            } else {
                highWater = max(highWater, now)
            }
            furthest = max(furthest, now)
        }

        // Looping repeatedly *is* the behaviour under test, and it is also the only honest
        // evidence that the picture never stopped: a paused picture cannot wrap twice. An
        // earlier version asserted `rateForTesting > 0` on each sample instead, which reads
        // zero for the instant of each seek, and then asserted a stall ratio, which a loaded
        // machine can exceed on seek latency alone. Neither measured looping.
        #expect(rewinds >= 2,
                "expected the picture to keep jumping back; saw \(rewinds) rewinds in 6s of a 0.6s line")

        // The guarantee is that looping does not let the line run on into the next shot, and
        // the fixture is a 9 s video. So anything that wrapped is far below this and anything
        // that played straight through is far above it. The slack is for the loop-back itself:
        // it is driven by a periodic observer on the *main queue*, and when the whole suite is
        // running that queue is contended, so the observer fires late and the picture overruns
        // before the seek lands. That delay is the test environment, not the app.
        #expect(furthest < line.endTime + 2.5,
                "looping ran past the line; reached \(furthest)")

        // Polled, not sampled: an instantaneous read can land inside a seek, where zero rate
        // is correct and momentary.
        let rolling = try await waitUntil(timeout: 2) { picture.rateForTesting > 0 }
        #expect(rolling, "looping left the picture stopped")
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
