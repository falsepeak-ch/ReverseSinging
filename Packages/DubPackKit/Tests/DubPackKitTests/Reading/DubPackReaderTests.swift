//
//  DubPackReaderTests.swift
//  DubPackKitTests
//

import Foundation
import Testing
@testable import DubPackKit

/// A three-line pack mirroring a real one: comma in a caption, an underscored multi-word
/// character, and wavs of known length.
private func makeHarryPack(in parent: URL, packInfo: Bool = true, backingTrack: Bool = true) throws -> PackBuilder {
    let pack = try PackBuilder(in: parent, named: "harry-dobby")
    if packInfo {
        try pack.packInfo([
            "title=\"Harry meets dobby full scene harry potter dub pack\"",
            "icon=\"001_Dobby.jpg\"",
            "authors=[\"Hollyfrogg\"]",
        ])
    }
    try pack.line("001_Dobby", at: 0, character: "Dobby", caption: "*Shrieking with joy*", audioDuration: 1)
    try pack.line(
        "005_Harry",
        at: 18.334,
        character: "Harry",
        caption: "not to be rude or anything, but this isn't a great time for me to have a house elf in my bedroom.",
        audioDuration: 2
    )
    try pack.line("018_Mr_Dursley", at: 78.306, character: "Mr Dursley", caption: "Oh! Don't mind that, it's just the cat.", audioDuration: 1.5)
    if backingTrack {
        try pack.silentWav("_backing_track.wav", duration: 90)
    }
    return pack
}

@Suite("Pack reader")
struct DubPackReaderTests {

    // MARK: - A Whole Pack

    @Test func readsThePackInfo() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.title == "Harry meets dobby full scene harry potter dub pack")
        #expect(reading.pack.authors == ["Hollyfrogg"])
        #expect(reading.pack.iconFile == "001_Dobby.jpg")
        #expect(reading.pack.backingTrackFile == "_backing_track.wav")
        #expect(reading.pack.lines.count == 3)
        #expect(reading.pack.provenance == .unknown)
    }

    @Test func aWholePackHasNoIssues() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.issues.isEmpty)
        #expect(reading.candidateLineCount == 3)
    }

    @Test func ordersLinesByStartTime() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.line("002_Dobby", at: 50, character: "Dobby")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.map(\.startTime) == [0, 18.334, 50, 78.306])
        #expect(reading.pack.lines.map(\.index) == [1, 5, 2, 18])
    }

    @Test func measuresEachLineFromItsReferenceAudio() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)

        let lines = try await DubPackReader.testing().read(at: pack.directory).pack.lines

        #expect(abs(lines[0].duration - 1.0) < 0.01)
        #expect(abs(lines[1].duration - 2.0) < 0.01)
        #expect(abs(lines[1].endTime - 20.334) < 0.01)
    }

    @Test func keepsCaptionPunctuation() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)

        let caption = try await DubPackReader.testing().read(at: pack.directory).pack.lines[1].caption

        #expect(caption.contains("not to be rude or anything, but"))
        #expect(caption.hasSuffix("in my bedroom."))
    }

    @Test func namesTheCharacterFromTheFileWhenTheEntryDoesNot() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.entry("020_Aunt_Petunia", ["caption=\"No character\"", "image=\"020_Aunt_Petunia.jpg\"", "dub_timestamps=[95.0]"])
        try pack.still("020_Aunt_Petunia.jpg")
        try pack.silentWav("020_Aunt_Petunia.wav")

        let lines = try await DubPackReader.testing().read(at: pack.directory).pack.lines

        #expect(lines[2].character == "Mr Dursley")
        #expect(lines.last?.character == "Aunt Petunia")
    }

    @Test(arguments: [
        ("018_Mr_Dursley", "Mr Dursley"),
        ("03-Peter Parker", "Peter Parker"),
        ("1. Yzma", "Yzma"),
        ("042", "042"),
    ])
    func derivesACharacterNameFromASlug(slug: String, name: String) {
        #expect(LineEntryReader.characterName(fromSlug: slug) == name)
    }

    // MARK: - Duration

    @Test func takesItsLengthFromTheBackingTrack() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)

        let duration = try await DubPackReader.testing().read(at: pack.directory).pack.duration

        #expect(abs(duration - 90) < 0.1)
    }

    @Test func fallsBackToTheEndOfTheLastLine() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url, backingTrack: false)

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.backingTrackFile == nil)
        #expect(abs(reading.pack.duration - (78.306 + 1.5)) < 0.05)
        #expect(reading.issues.isEmpty, "a pack that simply ships no backing track is not broken")
    }

    // MARK: - Video

    @Test func findsAPlayableSceneVideo() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url, backingTrack: false)
        try pack.h264Video("dub_video.mp4", duration: 120)

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.videoFile == "dub_video.mp4")
        #expect(abs(reading.pack.duration - 120) < 0.2, "with no backing track the video sets the length")
        #expect(await DubPackReader.testing().playableSceneVideo(in: pack.directory) == "dub_video.mp4")
    }

    /// An unconverted Theora file reads as a file and would show as a black rectangle.
    @Test func refusesAVideoThatCannotBeDecoded() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.write(Data(count: 4096), to: "dub_video.ogv")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.videoFile == nil)
        #expect(reading.issues == [.unplayableSceneVideo(file: "dub_video.ogv")])
        #expect(await DubPackReader.testing().playableSceneVideo(in: pack.directory) == nil)
    }

    @Test func doesNotGuessBetweenTwoUnnamedVideos() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.h264Video("take1.mp4")
        try pack.h264Video("take2.mp4")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.videoFile == nil)
        #expect(reading.issues == [.ambiguousSceneVideo(candidates: ["take1.mp4", "take2.mp4"])])
    }

    // MARK: - Pack Info

    /// The pack info names a pack; it does not make one.
    @Test func readsAPackWithoutPackInfoUnderItsFolderName() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url, packInfo: false)
        try pack.write("Thanks!", to: "readme.txt")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.title == "harry-dobby")
        #expect(reading.pack.authors.isEmpty)
        #expect(reading.pack.lines.count == 3)
        #expect(reading.issues == [.missingPackInfo(otherTextFiles: ["readme.txt"])])
    }

    @Test func notesAPackInfoInNoKnownEncoding() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url, packInfo: false)
        try pack.write(Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x89, 0x90]), to: "_pack_info.ini")

        let reading = try await DubPackReader.testing().read(at: pack.directory, fallbackTitle: "Fallback")

        #expect(reading.pack.title == "Fallback")
        #expect(reading.issues == [.unreadablePackInfo(file: "_pack_info.ini")])
    }

    @Test func notesAnIconThePackInfoNamesButDoesNotShip() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.packInfo(["title=\"Scene\"", "icon=\"cover.png\""])

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.iconFile == "001_Dobby.jpg")
        #expect(reading.issues == [.missingIcon(file: "cover.png")])
    }

    @Test func readsProvenanceInAnyEncoding() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write(
            "[data]\r\nsource=\"Les Misérables (1935)\"\r\nsource_url=\"https://example.org\"\r\nlicence=\"Domaine public\"\r\n",
            to: "pack_info.ini",
            encoding: .windowsCP1252
        )

        let provenance = DubPackReader.testing().provenance(in: pack.directory)

        #expect(provenance == PackProvenance(source: "Les Misérables (1935)", sourceURL: "https://example.org", rights: "Domaine public"))
    }

    // MARK: - Failures

    @Test func refusesAFolderWithNothingPackLikeInIt() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.still("IMG_0001.jpg")

        await #expect(throws: DubPackImportError.noPackFound) {
            try await DubPackReader.testing().read(at: pack.directory)
        }
    }

    /// Before `.ini` entries were read, the Shrek 2 pack failed here with nothing to say why.
    @Test func aPackWithNoLineEntriesSaysWhatItHolds() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.still("01_A.jpg")
        try pack.silentWav("01_A.wav")
        try pack.write("x", to: "01_A.cfg")

        await #expect(throws: DubPackImportError.noLines(issues: [
            .noLineEntries(fileTypes: ["cfg": 1, "ini": 1, "jpg": 1, "wav": 1]),
        ])) {
            try await DubPackReader.testing().read(at: pack.directory)
        }
    }

    @Test func refusesAFolderThatDoesNotExist() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }

        await #expect(throws: DubPackImportError.sourceMissing) {
            try await DubPackReader.testing().read(at: temp.appending("nothing-here"))
        }
    }

    /// The most broken packs need their explanation most: `noLines` carries every drop.
    @Test func aPackWithNoUsableLinesSaysWhy() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.entry("001_Hero", ["caption=\"Never timed\""])
        try pack.entry("002_Hero", ["dub_timestamps=[1.0]"])

        await #expect(throws: DubPackImportError.noLines(issues: [
            .droppedLine(file: "001_Hero.txt", reason: .missingTimestamp),
            .droppedLine(file: "002_Hero.txt", reason: .missingAudio),
        ])) {
            try await DubPackReader.testing().read(at: pack.directory)
        }
    }
}

// MARK: - Dropped Entries

@Suite("Pack reader: dropped entries")
struct DubPackReaderDroppedEntryTests {

    @Test func dropsOnlyTheLineWhoseAudioIsMissing() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.remove("005_Harry.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.map(\.slug) == ["001_Dobby", "018_Mr_Dursley"])
        #expect(reading.issues == [.droppedLine(file: "005_Harry.txt", reason: .missingAudio)])
        #expect(reading.candidateLineCount == 3)
    }

    @Test func dropsAnEntryWithNoTimestamp() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.entry("020_Aunt_Petunia", ["caption=\"Never timed\"", "dub_characters=[\"Aunt Petunia\"]"])

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.count == 3)
        #expect(reading.candidateLineCount == 4)
        #expect(reading.issues == [.droppedLine(file: "020_Aunt_Petunia.txt", reason: .missingTimestamp)])
    }

    /// A time that is there but is not a time is a different mistake from a missing one.
    @Test func separatesAnInvalidTimestampFromAMissingOne() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.entry("020_Vernon", ["dub_timestamps=[soon]"])
        try pack.silentWav("020_Vernon.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.issues == [.droppedLine(file: "020_Vernon.txt", reason: .invalidTimestamp)])
    }

    @Test func dropsANumberedEntryThatIsNotText() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.write(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D]), to: "021_Vernon.txt")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.issues == [.droppedLine(file: "021_Vernon.txt", reason: .unreadableText)])
    }

    /// A UTF-16 entry used to count as unreadable. It is read now, and judged on what it says.
    @Test func judgesAUTF16EntryOnItsContents() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.write(Data([0xFF, 0xFE, 0x41, 0x00]), to: "021_Vernon.txt")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.issues == [.droppedLine(file: "021_Vernon.txt", reason: .missingTimestamp)])
    }

    @Test func notesTimestampsBeyondTheFirst() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url)
        try pack.entry("030_Ron", ["dub_timestamps=[1.0, 20.0, 40.0]", "image=\"001_Dobby.jpg\""])
        try pack.silentWav("030_Ron.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.contains { $0.slug == "030_Ron" && $0.startTime == 1.0 })
        #expect(reading.issues == [.extraTimestampsIgnored(file: "030_Ron.txt", count: 2)])
    }

    @Test func notesABackingTrackThatCannotBeDecoded() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try makeHarryPack(in: temp.url, backingTrack: false)
        try pack.write(Data(count: 4096), to: "_backing_track.ogg")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.backingTrackFile == nil)
        #expect(reading.issues == [.unplayableBackingTrack(file: "_backing_track.ogg")])
    }
}
