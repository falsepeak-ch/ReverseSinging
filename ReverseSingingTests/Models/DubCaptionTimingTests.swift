//
//  DubCaptionTimingTests.swift
//  ReverseSingingTests
//
//  Subtitles that go up when the character speaks, not when the chunk starts
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Dub Caption Timing")
struct DubCaptionTimingTests {

    /// A line whose chunk opens at `start`, with `lead` seconds of room tone before the
    /// dialogue and the speech running for `speech` seconds after that.
    private func line(
        index: Int,
        start: TimeInterval,
        lead: TimeInterval,
        speech: TimeInterval,
        trailingSilence: TimeInterval = 0
    ) -> DubLine {
        DubLine(
            index: index,
            slug: String(format: "%03d_Tester", index),
            character: "Tester",
            caption: "Line \(index)",
            imageFile: "still.jpg",
            referenceAudioFile: "line.wav",
            startTime: start,
            duration: lead + speech + trailingSilence,
            speech: DubSpeechWindow(start: lead, end: lead + speech)
        )
    }

    private func pack(_ lines: [DubLine], duration: TimeInterval = 120) -> DubPack {
        DubPack(
            title: "Caption Scene",
            authors: [],
            iconFile: "still.jpg",
            backingTrackFile: nil,
            folderName: "captions",
            lines: lines,
            duration: duration
        )
    }

    // MARK: - The Bug This Exists For

    /// The whole point. A chunk that opens with two seconds of room tone must not put its
    /// caption on screen for those two seconds. That is the character's words appearing
    /// before their mouth moves, on every line, by a different amount each time.
    @Test func aCaptionDoesNotAppearDuringTheChunkRunUp() {
        let scene = pack([line(index: 1, start: 10, lead: 2.0, speech: 1.5)])

        // Just after the chunk begins, and still a beat and a half from the first word.
        #expect(scene.captionLine(at: 10.2) == nil,
                "the caption must not be up while the chunk is still room tone")

        // The old lookup is what the picture uses, and it does hold from the chunk's start.
        #expect(scene.line(at: 10.2)?.index == 1,
                "the still, by contrast, has to show something for every frame")
    }

    @Test func aCaptionIsUpWhileTheCharacterSpeaks() {
        let scene = pack([line(index: 1, start: 10, lead: 2.0, speech: 1.5)])

        #expect(scene.captionLine(at: 12.1)?.index == 1)
        #expect(scene.captionLine(at: 13.0)?.index == 1)
    }

    /// It goes up just before the first word, so the line can be read rather than caught.
    @Test func aCaptionLeadsTheFirstWordSlightly() {
        let scene = pack([line(index: 1, start: 10, lead: 2.0, speech: 1.5)])

        let speechStart = 12.0
        #expect(scene.captionLine(at: speechStart - 0.1)?.index == 1)
        #expect(scene.captionLine(at: speechStart - DubPack.captionLead - 0.1) == nil)
    }

    /// And comes down after it, rather than sitting there until the next line starts,
    /// which in a real scene can be thirty seconds of silence later.
    @Test func aCaptionClearsInTheGapBetweenLines() {
        let scene = pack([
            line(index: 1, start: 0, lead: 0.5, speech: 1.0),
            line(index: 2, start: 40, lead: 0.5, speech: 1.0)
        ])

        // Line one's speech ends at 1.5; well past the hold, nothing should be shown.
        #expect(scene.captionLine(at: 5) == nil)
        #expect(scene.captionLine(at: 30) == nil)

        // `line(at:)` would still be handing back line one here.
        #expect(scene.line(at: 30)?.index == 1)
    }

    @Test func aCaptionSurvivesJustPastTheLastWord() {
        let scene = pack([line(index: 1, start: 0, lead: 0.5, speech: 1.0)])

        let speechEnd = 1.5
        #expect(scene.captionLine(at: speechEnd + 0.2)?.index == 1)
        #expect(scene.captionLine(at: speechEnd + DubPack.captionHold + 0.2) == nil)
    }

    /// Two characters talking over each other: the one who came in last is the one being
    /// listened to, so that is the caption shown.
    @Test func overlappingDialogueShowsTheMostRecentSpeaker() {
        let scene = pack([
            line(index: 1, start: 0, lead: 0, speech: 4.0),
            line(index: 2, start: 2, lead: 0, speech: 2.0)
        ])

        #expect(scene.captionLine(at: 1.0)?.index == 1, "before the interruption")
        #expect(scene.captionLine(at: 2.5)?.index == 2, "during it")
    }

    // MARK: - Unmeasured Packs

    /// A pack imported before speech windows existed still has to work. Its lines fall back
    /// to the whole chunk, which is exactly the behaviour that shipped before.
    @Test func anUnmeasuredLineFallsBackToItsWholeChunk() {
        let unmeasured = DubLine(
            index: 1,
            slug: "001_Tester",
            character: "Tester",
            caption: "Line",
            imageFile: "still.jpg",
            referenceAudioFile: "line.wav",
            startTime: 10,
            duration: 3
        )

        #expect(unmeasured.speechLead == 0)
        #expect(unmeasured.speechStartTime == 10)
        #expect(unmeasured.speechEndTime == 13)
        #expect(!pack([unmeasured]).hasMeasuredSpeech)
    }

    @Test func aMeasuredPackReportsItself() {
        #expect(pack([line(index: 1, start: 0, lead: 0.2, speech: 1)]).hasMeasuredSpeech)
    }

    /// A manifest carrying nonsense. An end before its start, a window longer than the clip,
    /// must not produce a caption that closes before it opens or a placement past the line.
    @Test func anImpossibleWindowIsClampedRatherThanTrusted() {
        let broken = DubLine(
            index: 1,
            slug: "001_Tester",
            character: "Tester",
            caption: "Line",
            imageFile: "still.jpg",
            referenceAudioFile: "line.wav",
            startTime: 5,
            duration: 2,
            speech: DubSpeechWindow(start: 9, end: -1)
        )

        #expect(broken.speechLead <= broken.duration)
        #expect(broken.speechTail >= broken.speechLead)
        #expect(broken.speechEndTime >= broken.speechStartTime)
    }
}
