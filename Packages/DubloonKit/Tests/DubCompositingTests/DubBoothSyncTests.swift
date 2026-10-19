//
//  DubBoothSyncTests.swift
//  DubCompositingTests
//
//  The booth starts on the take's sample zero, and lands where the voice does
//

import Testing
import DubCompositing

@Suite("Booth Take Clock")
struct DubBoothTakeClockTests {

    private let frame = 1.0 / 30

    /// The warm camera: a frame just before the anchor stands in for sample zero, so the clip
    /// has a picture from its first instant.
    @Test func aFrameJustBeforeTheAnchorBecomesTheFirstPicture() {
        var clock = DubBoothTakeClock(anchor: 10, duration: 4)

        #expect(clock.step(forFrameAt: 10 - 3 * frame) == .drop, "the countdown is not the take")
        #expect(clock.step(forFrameAt: 10 - frame) == .stash)
        #expect(clock.step(forFrameAt: 10 + 0.01) == .write(at: 10 + 0.01, stashFirst: true))
        #expect(clock.step(forFrameAt: 10 + 0.01 + frame) == .write(at: 10 + 0.01 + frame, stashFirst: false))
    }

    /// The cold camera (switched on during the countdown): its first frame arrives after the
    /// anchor and is moved back onto it, so the take has no leading gap.
    @Test func aLateFirstFrameIsMovedBackToTheAnchor() {
        var clock = DubBoothTakeClock(anchor: 10, duration: 4)

        #expect(clock.step(forFrameAt: 10.25) == .write(at: 10, stashFirst: false))
        #expect(clock.step(forFrameAt: 10.25 + frame) == .write(at: 10.25 + frame, stashFirst: false),
                "only the first frame is moved; the rest keep their own time, which is what keeps sync")
    }

    @Test func aFrameExactlyOnTheAnchorIsWrittenAsIs() {
        var clock = DubBoothTakeClock(anchor: 10, duration: 4)
        _ = clock.step(forFrameAt: 10 - frame)

        #expect(clock.step(forFrameAt: 10) == .write(at: 10, stashFirst: false))
    }

    @Test func theTakeEndsWithTheLine() {
        var clock = DubBoothTakeClock(anchor: 10, duration: 4)
        _ = clock.step(forFrameAt: 10.01)

        #expect(clock.step(forFrameAt: 13.99) == .write(at: 13.99, stashFirst: false))
        #expect(clock.step(forFrameAt: 14) == .end)
    }

    @Test func anOpenEndedTakeNeverEndsByItself() {
        var clock = DubBoothTakeClock(anchor: 0, duration: 0)
        _ = clock.step(forFrameAt: 0.01)
        #expect(clock.step(forFrameAt: 600) == .write(at: 600, stashFirst: false))
    }

    /// A frame that arrives out of order after the take started is never written backwards.
    @Test func aStaleFrameAfterTheStartIsDropped() {
        var clock = DubBoothTakeClock(anchor: 10, duration: 4)
        _ = clock.step(forFrameAt: 10.01)
        #expect(clock.step(forFrameAt: 9.99) == .drop)
    }
}

@Suite("Booth Export Placement")
struct DubBoothPlacementTests {

    /// The whole scene: the clip goes in at the line's own time, all of it.
    @Test func inTheFullSceneTheClipLandsWhereTheVoiceDoes() throws {
        let placement = try #require(DubBoothPlacement.place(
            lineStart: 12, lineEnd: 15,
            segmentStart: 0, segmentEnd: 60,
            segmentOutputStart: 0,
            clipDuration: 3
        ))

        #expect(placement.clipStart == 0)
        #expect(placement.duration == 3)
        #expect(placement.outputStart == 12, "the same offset the mixer places the take at")
    }

    /// The session reel drops the gaps: the clip follows its segment, not scene time.
    @Test func inTheReelTheClipFollowsItsSegment() throws {
        let placement = try #require(DubBoothPlacement.place(
            lineStart: 30, lineEnd: 32,
            segmentStart: 30, segmentEnd: 32,
            segmentOutputStart: 5,
            clipDuration: 2
        ))
        #expect(placement.outputStart == 5)
        #expect(placement.clipStart == 0)
    }

    /// A scene that ends mid-line takes the head of the clip.
    @Test func aCutEndingMidLineTrimsTheTail() throws {
        let placement = try #require(DubBoothPlacement.place(
            lineStart: 58, lineEnd: 62,
            segmentStart: 0, segmentEnd: 60,
            segmentOutputStart: 0,
            clipDuration: 4
        ))
        #expect(placement.duration == 2)
        #expect(placement.outputStart == 58)
    }

    /// A segment that starts mid-line reads the clip from the same point the voice is at.
    @Test func aCutStartingMidLineSkipsTheHead() throws {
        let placement = try #require(DubBoothPlacement.place(
            lineStart: 10, lineEnd: 14,
            segmentStart: 11, segmentEnd: 20,
            segmentOutputStart: 0,
            clipDuration: 4
        ))
        #expect(placement.clipStart == 1)
        #expect(placement.duration == 3)
        #expect(placement.outputStart == 0)
    }

    @Test func aShortClipIsNeverReadPastItsEnd() throws {
        let placement = try #require(DubBoothPlacement.place(
            lineStart: 0, lineEnd: 4,
            segmentStart: 0, segmentEnd: 4,
            segmentOutputStart: 0,
            clipDuration: 2.5
        ))
        #expect(placement.duration == 2.5)
    }

    @Test func aLineOutsideTheSegmentIsNotPlaced() {
        #expect(DubBoothPlacement.place(
            lineStart: 0, lineEnd: 2,
            segmentStart: 5, segmentEnd: 8,
            segmentOutputStart: 0,
            clipDuration: 2
        ) == nil)
    }
}
