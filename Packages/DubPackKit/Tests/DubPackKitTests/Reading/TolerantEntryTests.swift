//
//  TolerantEntryTests.swift
//  DubPackKitTests
//
//  Entries the format never described, as the packs people actually make write them
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("Tolerant entries")
struct TolerantEntryTests {

    @Test func anUnnumberedTextWithARecordingBesideItIsALine() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "handmade")
        try pack.packInfo()
        try pack.write("Why don't I know you?", to: "cady.txt")
        try pack.silentWav("cady.wav")
        try pack.write("Thanks for playing", to: "readme.txt")

        // Plain text with a recording beside it is an entry, and one with no time is a lost
        // line; the readme, with nothing beside it, is a note.
        await #expect(throws: DubPackImportError.noLines(issues: [
            .droppedLine(file: "cady.txt", reason: .missingTimestamp),
        ])) {
            try await DubPackReader.testing().read(at: pack.directory)
        }
    }

    @Test func readsTheTimeFromTheFileNameWhenTheEntryHasNone() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "named-times")
        try pack.packInfo()
        try pack.write("Why don't I know you?", to: "01_Cady_12.5.txt")
        try pack.silentWav("01_Cady_12.5.wav")
        try pack.still("01_Cady_12.5.jpg")
        try pack.entry("02_Regina", ["caption=\"So fetch\""])
        try pack.silentWav("02_Regina.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.map(\.startTime) == [12.5])
        #expect(reading.pack.lines.first?.caption == "Why don't I know you?")
        #expect(reading.pack.lines.first?.character == "Cady 12.5")
        #expect(reading.issues == [.droppedLine(file: "02_Regina.txt", reason: .missingTimestamp)])
    }

    @Test(arguments: [
        ("01_Cady_12.5", "12.5"),
        ("Cady@1:23", "1:23"),
        ("07 - Regina (1m23s)", "1m23s"),
        ("03-Peter Parker 2", nil),
        ("018_Mr_Dursley", nil),
        ("12.5", nil),
    ])
    func findsATimeInAStemOnlyWhenItLooksLikeOne(stem: String, expected: String?) {
        #expect(LineEntryReader.timestamp(inStem: stem) == expected)
    }

    @Test func reportsTheUnparseableTimestampText() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "odd-times")
        try pack.packInfo()
        try pack.entry("001_Hero", ["dub_timestamps=[\"twelve and a half\"]"])
        try pack.silentWav("001_Hero.wav")
        try pack.line("002_Hero", at: 3)

        let reading = try await DubPackReader.testing().read(at: pack.directory)
        let report = DubPackIssueReport.reports(for: reading.issues, packTitle: "t", candidateLineCount: 2, keptLineCount: 1)

        #expect(reading.issues == [.droppedLine(file: "001_Hero.txt", reason: .invalidTimestamp, detail: "twelve and a half")])
        #expect(report.first?.keys["detail_sample"] == .string("twelve and a half"))
    }

    @Test func readsSRTStyleAndRangeTimestamps() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "formats")
        try pack.packInfo()
        for (slug, time) in [("001_A", "00:00:12,466"), ("002_A", "1:02.5 - 1:05"), ("003_A", "1m30s")] {
            try pack.entry(slug, ["dub_timestamps=[\"\(time)\"]"])
            try pack.silentWav("\(slug).wav")
            try pack.still("\(slug).jpg")
        }

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.map(\.startTime) == [12.466, 62.5, 90])
        #expect(reading.issues.isEmpty)
    }

    @Test func findsAnIconNamedWithTheWrongExtension() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "icon")
        try pack.packInfo(["title=\"Icon\"", "icon=\"icon.png\""])
        try pack.still("icon.jpg")
        try pack.line("001_A", at: 0)

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.iconFile == "icon.jpg")
        #expect(!reading.issues.contains(.missingIcon(file: "icon.png")))
    }

    @Test func aStemLookupNeverCrossesKinds() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "kinds")
        try pack.write("x", to: "001_A.txt")
        try pack.still("001_A.jpg")
        let folder = try #require(PackDirectory(url: pack.directory))

        #expect(folder.file(named: "001_A.wav") == nil)
        #expect(folder.file(named: "001_A.png")?.name == "001_A.jpg")
    }

    @Test func findsAnIconByAStemThatMentionsIt() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "icon-stem")
        try pack.still("001_A.jpg")
        try pack.still("scene_icon.png")
        let folder = try #require(PackDirectory(url: pack.directory))

        #expect(folder.conventionalIcon?.name == "scene_icon.png")
    }
}
