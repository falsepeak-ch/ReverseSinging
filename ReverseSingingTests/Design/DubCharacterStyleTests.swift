//
//  DubCharacterStyleTests.swift
//  ReverseSingingTests
//
//  Every character in a scene drawn in a colour of its own
//

import Testing
@testable import ReverseSinging

@Suite("Dub Character Style") @MainActor
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
