//
//  PackFieldsTests.swift
//  DubPackKitTests
//

import Testing
@testable import DubPackKit

@Suite("Pack fields")
struct PackFieldsTests {

    @Test func readsQuotedScalars() {
        let fields = PackFields(parsing: """
        [data]

        title="Harry meets dobby"
        icon="001_Dobby.jpg"
        """)

        #expect(fields["title"]?.first == "Harry meets dobby")
        #expect(fields["icon"]?.first == "001_Dobby.jpg")
    }

    @Test func keepsCommasInsideQuotedValues() {
        let caption = "not to be rude or anything, but this isn't a great time"

        #expect(PackFields(parsing: "caption=\"\(caption)\"")["caption"]?.first == caption)
        #expect(PackFields(parsing: "dub_characters=[\"Smith, Agent\", \"Neo\"]")["dub_characters"]?.all == ["Smith, Agent", "Neo"])
    }

    @Test func readsLists() {
        let fields = PackFields(parsing: """
        dub_timestamps=[1.5, 9.25]
        dub_characters=["Harry", "Ron"]
        authors=["Hollyfrogg"]
        """)

        #expect(fields["dub_timestamps"]?.all == ["1.5", "9.25"])
        #expect(fields["dub_characters"]?.all == ["Harry", "Ron"])
        #expect(fields["authors"]?.all == ["Hollyfrogg"])
    }

    @Test func splitsOnTheFirstEqualsOnly() {
        #expect(PackFields(parsing: "caption=\"x = y, and z = w\"")["caption"]?.first == "x = y, and z = w")
    }

    @Test func skipsSectionsCommentsAndBlankLines() {
        let fields = PackFields(parsing: """
        [data]
        # a comment
        ; another

        title="Something"

        """)

        #expect(fields.keys == ["title"])
    }

    @Test func unescapesQuotesInsideValues() {
        #expect(PackFields(parsing: #"caption="he said \"hello\" loudly""#)["caption"]?.first == #"he said "hello" loudly"#)
    }

    @Test func ignoresTheCaseOfKeys() {
        let fields = PackFields(parsing: "Caption=\"Hi\"\nDUB_Timestamps=[2.5]\n")

        #expect(fields["caption"]?.first == "Hi")
        #expect(fields["dub_timestamps"]?.all == ["2.5"])
    }

    /// The in-house pack builders write `key = value` with spaces around the `=`.
    @Test func toleratesSpacesAroundEquals() {
        let fields = PackFields(parsing: "dub_timestamps = [1.250]\ncaption = \"Spaced\"")

        #expect(fields["dub_timestamps"]?.all == ["1.250"])
        #expect(fields["caption"]?.first == "Spaced")
    }

    @Test func acceptsSingleQuotedAndBareValues() {
        #expect(PackFields.unquote("'Hello'") == "Hello")
        #expect(PackFields.unquote("\"Hello\"") == "Hello")
        #expect(PackFields.unquote("Hello") == "Hello")
    }

    @Test func picksTheFirstKeyThatHasAValue() {
        let fields = PackFields(parsing: "title=\"  \"\nname=\"Fallback\"")

        #expect(fields.string(["title", "name"]) == "Fallback")
        #expect(fields.list(["authors", "author"]) == [])
    }
}
