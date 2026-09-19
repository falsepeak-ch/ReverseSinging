//
//  TimecodeFormattingTests.swift
//  DubloonFoundationTests
//
//  The clocks and frame names the interface shows
//

import CoreGraphics
import Foundation
import Testing
import DubloonFoundation

@Suite("Timecode Formatting")
struct TimecodeFormattingTests {

    // MARK: - Clocks

    @Test func theClockShowsWholeMinutesAndSeconds() {
        #expect(TimeInterval(0).rsClock == "00:00")
        #expect(TimeInterval(75.9).rsClock == "01:15", "never rounds up into the next second")
    }

    /// Past an hour the minutes keep counting, which is what a take counter should do.
    @Test func anHourIsStillCountedInMinutes() {
        #expect(TimeInterval(3_725).rsClock == "62:05")
    }

    @Test func aRunningTakeShowsHundredths() {
        #expect(TimeInterval(75.25).rsClockHundredths == "01:15.25")
        #expect(TimeInterval(3).rsClockHundredths == "00:03.00")
    }

    @Test func theScrubberCountsFramesAtTwentyFour() {
        #expect(TimeInterval(61.5).rsClockFrames == "01:01:12")
        #expect(TimeInterval(1.99).rsClockFrames == "00:01:23")
    }

    // MARK: - Frame Shapes

    @Test(arguments: [
        (CGSize(width: 1920, height: 1080), "16:9"),
        (CGSize(width: 1080, height: 1920), "9:16"),
        (CGSize(width: 480, height: 360), "4:3"),
        (CGSize(width: 1000, height: 1000), "1:1"),
        (CGSize(width: 1998, height: 1080), "1.85:1"),
        (CGSize(width: 1912, height: 800), "2.39:1"),
        // Within a percent: the layout's even-number rounding does not make a new shape.
        (CGSize(width: 1080, height: 606), "16:9"),
    ])
    func aRecognisedShapeIsNamedTheWayASlateNamesIt(size: CGSize, label: String) {
        #expect(size.rsAspectLabel == label)
    }

    @Test func anUnrecognisedShapeIsGivenAsADecimal() {
        #expect(CGSize(width: 1250, height: 1000).rsAspectLabel == "1.25:1")
        #expect(CGSize(width: 1000, height: 1250).rsAspectLabel == "1:1.25")
    }

    @Test func aShapeWithNoSizeHasNoName() {
        #expect(CGSize.zero.rsAspectLabel == "—")
    }
}

@Suite("Nil If Empty")
struct NilIfEmptyTests {

    @Test func surroundingWhitespaceIsTrimmed() {
        #expect("  Dobby \n".nilIfEmpty == "Dobby")
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func nothingLeftIsNil(value: String) {
        #expect(value.nilIfEmpty == nil)
    }
}
