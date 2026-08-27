//
//  DubVoiceLanesTests.swift
//  ReverseSingingTests
//
//  Overlapping dialogue landing on separate nodes so it can be mixed
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Dub Voice Lanes")
struct DubVoiceLanesTests {

    private struct Span {
        let name: String
        let start: TimeInterval
        let end: TimeInterval
    }

    private func lanes(_ spans: [Span]) -> [[String]] {
        DubVoiceLanes.assign(spans, start: { $0.start }, end: { $0.end })
            .map { $0.map(\.name) }
    }

    /// The whole reason the type exists: two characters talking over each other cannot share a
    /// player node, because a node renders one buffer at a time and would queue the second.
    @Test func overlappingLinesGoToDifferentLanes() {
        let result = lanes([
            Span(name: "a", start: 0, end: 3),
            Span(name: "b", start: 2, end: 5)
        ])

        #expect(result.count == 2)
        #expect(result[0] == ["a"])
        #expect(result[1] == ["b"])
    }

    /// And the ordinary case must not multiply nodes: a scene of one line after another is
    /// still one lane, which is what keeps timing from drifting between them.
    @Test func sequentialLinesShareOneLane() {
        let result = lanes([
            Span(name: "a", start: 0, end: 2),
            Span(name: "b", start: 4, end: 6),
            Span(name: "c", start: 8, end: 10)
        ])

        #expect(result == [["a", "b", "c"]])
    }

    /// A line beginning exactly where the last one ended does not overlap it.
    @Test func linesThatAbutShareOneLane() {
        let result = lanes([
            Span(name: "a", start: 0, end: 2),
            Span(name: "b", start: 2, end: 4)
        ])

        #expect(result == [["a", "b"]])
    }

    /// Lanes are reused as they free up rather than accumulating.
    @Test func alaneIsReusedOnceItsLineHasFinished() {
        let result = lanes([
            Span(name: "a", start: 0, end: 4),
            Span(name: "b", start: 1, end: 2),
            Span(name: "c", start: 3, end: 5)
        ])

        #expect(result.count == 2)
        #expect(result[0] == ["a"])
        #expect(result[1] == ["b", "c"])
    }

    /// Input order should not matter. A pack can list its lines however it likes.
    @Test func handlesLinesGivenOutOfOrder() {
        let result = lanes([
            Span(name: "late", start: 5, end: 7),
            Span(name: "early", start: 0, end: 2)
        ])

        #expect(result == [["early", "late"]])
    }

    /// A malformed pack that stacks every line on the same timestamp must not ask the engine
    /// for a node per line. Past the cap they queue, which is the old behaviour.
    @Test func stopsAtTheLaneCap() {
        let spans = (0..<40).map { Span(name: "\($0)", start: 0, end: 10) }
        let result = lanes(spans)

        #expect(result.count == DubVoiceLanes.maximumLanes)
        #expect(result.flatMap { $0 }.count == 40)
    }

    @Test func emptyInGivesEmptyOut() {
        #expect(lanes([]).isEmpty)
    }

    /// Timestamps and measured lengths taken from a real pack, the Dobby scene, where two
    /// characters talk over each other for a sixth of the runtime. Synthetic fixtures can be
    /// made to overlap; this is proof that packs in the wild actually do.
    @Test func aRealSceneNeedsMoreThanOneLane() {
        let scene = [
            Span(name: "003_Harry", start: 12.59, end: 13.73),
            Span(name: "004_Dobby", start: 13.61, end: 18.00),
            Span(name: "029_Dobby", start: 130.00, end: 139.46),
            Span(name: "030_Harry", start: 134.21, end: 138.01),
            Span(name: "046_Dobby", start: 184.48, end: 192.22),
            Span(name: "047_Harry", start: 184.51, end: 192.58)
        ]

        let result = lanes(scene)
        #expect(result.count > 1)

        func lane(of name: String) -> Int? {
            result.firstIndex { $0.contains(name) }
        }

        // Harry cutting in on the end of a Dobby line
        #expect(lane(of: "003_Harry") != lane(of: "004_Dobby"))

        // Harry speaking entirely inside a Dobby line
        #expect(lane(of: "029_Dobby") != lane(of: "030_Harry"))

        // Both of them, for nearly eight seconds together
        #expect(lane(of: "046_Dobby") != lane(of: "047_Harry"))
    }
}

@Suite("Dub Character Style")
struct DubCharacterStyleTests {

    /// Two characters in the same scene must never be the same colour, or the colour tells the
    /// performer nothing.
    @Test func castMembersGetDistinctColours() {
        let cast = ["Dobby", "Harry", "Mr Dursley"]
        let colours = cast.map { DubCharacterStyle.color(for: $0, in: cast) }

        #expect(Set(colours.map(String.init(describing:))).count == cast.count)
    }

    /// Keyed on the cast position, so a character keeps its colour across launches.
    @Test func aCharacterKeepsTheSameColour() {
        let cast = ["Dobby", "Harry"]

        #expect(
            DubCharacterStyle.color(for: "Harry", in: cast)
                == DubCharacterStyle.color(for: "Harry", in: cast)
        )
        #expect(
            DubCharacterStyle.color(for: "Harry", in: cast)
                != DubCharacterStyle.color(for: "Dobby", in: cast)
        )
    }

    /// A line whose character is not in the cast still has to draw something.
    @Test func fallsBackForAnUnknownCharacter() {
        #expect(DubCharacterStyle.color(for: "Nobody", in: ["Dobby"]) == .rsTextSecondary)
    }
}
