//
//  DubPackTimelineTests.swift
//  ReverseSingingTests
//
//  Finding the line on screen at a moment in the scene
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Dub Timeline Lookup")
struct DubTimelineTests {

    /// Three lines with gaps between them, the shape of the Harry and Dobby scene.
    private func makePack() -> DubPack {
        func line(_ index: Int, _ slug: String, _ character: String, at start: TimeInterval, for duration: TimeInterval) -> DubLine {
            DubLine(
                index: index, slug: slug, character: character, caption: "",
                imageFile: "\(slug).jpg", referenceAudioFile: "\(slug).wav",
                startTime: start, duration: duration
            )
        }

        return DubPack(
            title: "Harry meets dobby",
            authors: ["Hollyfrogg"],
            iconFile: "001_Dobby.jpg",
            backingTrackFile: "_backing_track.wav",
            folderName: "harry-dobby",
            lines: [
                line(1, "001_Dobby", "Dobby", at: 0, for: 1),
                line(5, "005_Harry", "Harry", at: 18.334, for: 2),
                line(18, "018_Mr_Dursley", "Mr Dursley", at: 78.306, for: 1.5),
            ],
            duration: 90
        )
    }

    @Test func findsTheLinePlayingAtATime() {
        let pack = makePack()

        #expect(pack.line(at: 0.0)?.slug == "001_Dobby")
        #expect(pack.line(at: 18.5)?.slug == "005_Harry")
        #expect(pack.line(at: 100.0)?.slug == "018_Mr_Dursley")
    }

    @Test func holdsThePreviousLineThroughGaps() {
        // 10s is past line 1's end but before line 5 starts.
        #expect(makePack().line(at: 10.0)?.slug == "001_Dobby")
    }

    @Test func clampsBeforeTheFirstLine() {
        #expect(makePack().line(at: -5)?.slug == "001_Dobby")
    }

    @Test func listsCharactersInOrderOfFirstAppearance() {
        #expect(makePack().characters == ["Dobby", "Harry", "Mr Dursley"])
    }
}
