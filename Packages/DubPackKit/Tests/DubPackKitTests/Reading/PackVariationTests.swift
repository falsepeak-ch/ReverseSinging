//
//  PackVariationTests.swift
//  DubPackKitTests
//
//  The shapes packs actually arrive in, as against the one the format describes
//

import Foundation
import Testing
@testable import DubPackKit

// MARK: - Line Assets

@Suite("Pack variations: line assets")
struct LineAssetVariationTests {

    /// Half the community packs that prompted this suite ship `.mp3` lines with `.png` stills.
    /// Every one of them used to fail on its first line.
    @Test func readsMp3LinesWithPngStills() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.entry("01_Shang", ["image=\"01_Shang.png\"", "dub_timestamps=[6.716]", "dub_characters=[\"Shang\"]"])
        try pack.write(Data([0x89, 0x50, 0x4E, 0x47]), to: "01_Shang.png")
        try pack.copyFixture("line.mp3", as: "01_Shang.mp3")

        let reading = try await DubPackReader.testing().read(at: pack.directory)
        let line = try #require(reading.pack.lines.first)

        #expect(line.referenceAudioFile == "01_Shang.mp3")
        #expect(line.imageFile == "01_Shang.png")
        #expect(line.character == "Shang")
        #expect(abs(line.duration - 0.5) < 0.1)
        #expect(reading.issues.isEmpty)
    }

    @Test func prefersTheWavWhenAnMp3OfTheSameLineExists() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.line("001_Hero", at: 1)
        try pack.copyFixture("line.mp3", as: "001_Hero.mp3")

        let line = try await DubPackReader.testing().read(at: pack.directory).pack.lines[0]

        #expect(line.referenceAudioFile == "001_Hero.wav")
    }

    /// One of the two being broken should not cost the line.
    @Test func fallsThroughToTheNextAudioWhenTheFirstWillNotDecode() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.line("001_Hero", at: 1)
        try pack.copyFixture("line.mp3", as: "001_Hero.mp3")

        let probe = StubMediaProbe(undecodable: ["001_Hero.wav"])
        let line = try await DubPackReader.testing(probe: probe).read(at: pack.directory).pack.lines[0]

        #expect(line.referenceAudioFile == "001_Hero.mp3")
    }

    @Test func readsAudioTheEntryNames() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.entry("001_Hero", ["image=\"001_Hero.jpg\"", "dub_timestamps=[1.0]", "audio=\"voices/hero_take.wav\""])
        try pack.still("001_Hero.jpg")
        try pack.silentWav("hero_take.wav")

        let line = try await DubPackReader.testing().read(at: pack.directory).pack.lines[0]

        #expect(line.referenceAudioFile == "hero_take.wav")
    }

    /// Reported as unplayable rather than missing, which points the author at the format.
    @Test func dropsALineWhoseAudioWillNotDecode() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.line("001_Hero", at: 1)
        try pack.entry("002_Hero", ["image=\"002_Hero.jpg\"", "dub_timestamps=[2.0]"])
        try pack.still("002_Hero.jpg")
        try pack.copyFixture("line.ogg", as: "002_Hero.ogg")

        let probe = StubMediaProbe(undecodable: ["002_Hero.ogg"])
        let reading = try await DubPackReader.testing(probe: probe).read(at: pack.directory)

        #expect(reading.pack.lines.count == 1)
        #expect(reading.issues == [.droppedLine(file: "002_Hero.txt", reason: .unplayableAudio)])
    }

    /// The reader follows whatever the platform decodes, rather than assuming Ogg never plays.
    @Test func agreesWithThePlatformAboutOggAudio() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.line("001_Hero", at: 1)
        try pack.entry("002_Hero", ["image=\"001_Hero.jpg\"", "dub_timestamps=[2.0]"])
        try pack.copyFixture("line.ogg", as: "002_Hero.ogg")

        let platformDecodesOgg = AVFoundationMediaProbe().audioDuration(of: pack.directory.appendingPathComponent("002_Hero.ogg")) != nil
        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.count == (platformDecodesOgg ? 2 : 1))
    }

    /// A missing still costs a picture, not a line: the previous line's still stands in.
    @Test func keepsALineWhoseStillIsMissing() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.line("001_Hero", at: 1)
        try pack.entry("002_Hero", ["image=\"002_Hero.jpg\"", "dub_timestamps=[2.0]"])
        try pack.silentWav("002_Hero.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.count == 2)
        #expect(reading.pack.lines[1].imageFile == "001_Hero.jpg")
        #expect(reading.issues == [.missingStill(file: "002_Hero.txt", substitute: "001_Hero.jpg")])
    }

    @Test func findsTheStillBesideTheEntryWhenTheNamedOneIsWrong() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.entry("001_Hero", ["image=\"001_Hero.jpg\"", "dub_timestamps=[1.0]"])
        try pack.write(Data([0x89, 0x50, 0x4E, 0x47]), to: "001_Hero.png")
        try pack.silentWav("001_Hero.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines[0].imageFile == "001_Hero.png")
        #expect(reading.issues.contains { $0.kind == .missingStills } == false)
    }

    @Test func matchesAssetNamesRegardlessOfCase() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.entry("001_Hero", ["image=\"001_HERO.JPG\"", "dub_timestamps=[1.0]"])
        try pack.still("001_Hero.jpg")
        try pack.silentWav("001_Hero.wav")

        let line = try await DubPackReader.testing().read(at: pack.directory).pack.lines[0]

        #expect(line.imageFile == "001_Hero.jpg")
    }
}

// MARK: - Text

@Suite("Pack variations: text")
struct TextVariationTests {

    /// The Italian packs: CRLF endings, curly quotes and the character in brackets.
    @Test func readsWindowsLineEndingsAndCurlyQuotes() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo(["title=\"Io mi chiamo Ping - Mulan\"", "icon=\"icon.png\"", "authors=[\"Lily Moonlight\"]", "readme=\"\""], lineEnding: "\r\n")
        try pack.entry(
            "01_Shang",
            ["caption=\"[Shang] “Non voglio gente che pianti grane nel mio campo.”\"", "image=\"01_Shang.jpg\"", "dub_timestamps=[6.716]", "dub_characters=[\"Shang\"]"],
            lineEnding: "\r\n"
        )
        try pack.still("01_Shang.jpg")
        try pack.still("icon.png")
        try pack.silentWav("01_Shang.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.title == "Io mi chiamo Ping - Mulan")
        #expect(reading.pack.iconFile == "icon.png")
        #expect(reading.pack.lines[0].caption == "[Shang] “Non voglio gente che pianti grane nel mio campo.”")
        #expect(reading.pack.lines[0].startTime == 6.716)
    }

    /// The Shrek 2 and Forrest Gump packs: entries written as `.ini`, a blank line holding a space,
    /// an apostrophe and a space in a name, and two characters sharing one number.
    @Test func readsLineEntriesWrittenAsIni() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "Shrek 2 - Fiona's Diary")
        try pack.packInfo(["title=\"Shrek 2 - Fiona's Diary\"", "icon=\"icon.jpg\"", "authors=[\"corncobular\"]"])
        try pack.write("[data]\n \ncaption=\"“[Fiona] (grunting, shifting in bed)”\"\ndub_timestamps=[2.171917]\ndub_characters=[\"Fiona\"]\n", to: "01_Fiona.ini")
        try pack.write("[data]\n \ncaption=\"“[Fiona's Dad] S-sorry.”\"\ndub_timestamps=[58.797479]\ndub_characters=[\"Fiona's Dad\"]\n", to: "01_Fiona's Dad.ini")
        try pack.still("01_Fiona.jpg")
        try pack.still("01_Fiona's Dad.jpg")
        try pack.still("icon.jpg")
        try pack.copyFixture("line.mp3", as: "01_Fiona.mp3")
        try pack.copyFixture("line.mp3", as: "01_Fiona's Dad.mp3")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.issues.isEmpty)
        #expect(reading.candidateLineCount == 2)
        #expect(reading.pack.lines.map(\.slug) == ["01_Fiona", "01_Fiona's Dad"])
        #expect(reading.pack.lines.map(\.character) == ["Fiona", "Fiona's Dad"])
        #expect(reading.pack.lines.map(\.imageFile) == ["01_Fiona.jpg", "01_Fiona's Dad.jpg"])
        #expect(reading.pack.lines[0].caption == "“[Fiona] (grunting, shifting in bed)”")
    }

    @Test func readsAWindows1252Entry() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write("[data]\r\ncaption=\"Où est le café ?\"\r\nimage=\"001_Hero.jpg\"\r\ndub_timestamps=[1.0]\r\n", to: "001_Hero.txt", encoding: .windowsCP1252)
        try pack.still("001_Hero.jpg")
        try pack.silentWav("001_Hero.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines[0].caption == "Où est le café ?")
    }

    @Test func readsAPackInfoWithAByteOrderMark() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write("\u{FEFF}[data]\ntitle=\"Marked\"\n", to: "_pack_info.ini")
        try pack.line("001_Hero", at: 1)

        #expect(try await DubPackReader.testing().read(at: pack.directory).pack.title == "Marked")
    }

    @Test func ignoresNotesThatAreNotEntries() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.line("001_Hero", at: 1)
        try pack.write("Thanks for downloading!", to: "readme.txt")
        try pack.write("Credits: me.", to: "Credits.txt")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.lines.count == 1)
        #expect(reading.candidateLineCount == 1)
        #expect(reading.issues.isEmpty)
    }

    /// An unnumbered entry still counts when it carries line keys.
    @Test func readsAnUnnumberedEntryByItsKeys() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.entry("hero", ["caption=\"Hi\"", "dub_timestamp=3,25", "image=\"hero.jpg\""])
        try pack.still("hero.jpg")
        try pack.silentWav("hero.wav")

        let line = try await DubPackReader.testing().read(at: pack.directory).pack.lines[0]

        #expect(line.index == 1)
        #expect(line.startTime == 3.25)
        #expect(line.character == "hero")
    }
}

// MARK: - Pack Files

@Suite("Pack variations: pack files")
struct PackFileVariationTests {

    @Test func findsABackingTrackUnderAnotherNameAndExtension() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.line("001_Hero", at: 1)
        try pack.silentWav("Backing_Track.wav", duration: 30)

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.backingTrackFile == "Backing_Track.wav")
        #expect(abs(reading.pack.duration - 30) < 0.01)
    }

    @Test func takesTheOnlyUnclaimedAudioAsTheBackingTrack() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.line("001_Hero", at: 1)
        try pack.silentWav("music.wav", duration: 20)

        #expect(try await DubPackReader.testing().read(at: pack.directory).pack.backingTrackFile == "music.wav")
    }

    @Test func doesNotGuessBetweenTwoUnclaimedAudioFiles() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.line("001_Hero", at: 1)
        try pack.silentWav("music.wav")
        try pack.silentWav("ambience.wav")

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.backingTrackFile == nil)
        #expect(reading.issues == [.ambiguousBackingTrack(candidates: ["ambience.wav", "music.wav"])])
    }

    @Test(arguments: ["pack_info.ini", "_PackInfo.ini", "_pack_info.txt"])
    func readsThePackInfoUnderAnAlternativeName(name: String) async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo(["title=\"Alt Named\""], named: name)
        try pack.line("001_Hero", at: 1)

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.pack.title == "Alt Named")
        #expect(reading.issues.isEmpty)
    }

    @Test func usesIconPngWhenThePackInfoNamesNoIcon() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.line("001_Hero", at: 1)
        try pack.still("icon.png")

        #expect(try await DubPackReader.testing().read(at: pack.directory).pack.iconFile == "icon.png")
    }

    @Test func fallsBackToTheFirstLinesStillForTheIcon() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo()
        try pack.line("002_Hero", at: 5)
        try pack.line("001_Hero", at: 1)

        #expect(try await DubPackReader.testing().read(at: pack.directory).pack.iconFile == "001_Hero.jpg")
    }

    /// What `build_clip_pack.py` writes for the starter packs: spaced `=`, stills shared
    /// between lines, an AAC bed, an MP4 scene and provenance.
    @Test func readsAPackShapedLikeTheStarterPacks() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "CampRules")
        try pack.packInfo([
            "title = \"Camp Rules\"",
            "icon = \"shot_1.jpg\"",
            "authors = [\"Blender Studio\"]",
            "source = \"Sprite Fright (2021), Blender Studio\"",
            "source_url = \"https://studio.blender.org/projects/sprite-fright/\"",
            "rights = \"CC BY 4.0 - https://creativecommons.org/licenses/by/4.0/\"",
        ])
        for (slug, at, character) in [("001_Rex", 1.0, "Rex"), ("002_Ellie", 2.5, "Ellie"), ("003_Rex", 4.0, "Rex")] {
            try pack.entry(slug, ["caption = \"Line\"", "dub_timestamps = [\(at)]", "dub_characters = [\"\(character)\"]", "image = \"shot_1.jpg\""])
            try pack.silentWav("\(slug).wav")
        }
        try pack.still("shot_1.jpg")
        try pack.silentAAC("_backing_track.m4a", duration: 6)
        try pack.h264Video("dub_video.mp4", duration: 6)

        let reading = try await DubPackReader.testing().read(at: pack.directory)

        #expect(reading.issues.isEmpty)
        #expect(reading.pack.title == "Camp Rules")
        #expect(reading.pack.lines.map(\.character) == ["Rex", "Ellie", "Rex"])
        #expect(reading.pack.lines.allSatisfy { $0.imageFile == "shot_1.jpg" })
        #expect(reading.pack.backingTrackFile == "_backing_track.m4a")
        #expect(reading.pack.videoFile == "dub_video.mp4")
        #expect(abs(reading.pack.duration - 6) < 0.2)
        #expect(reading.pack.provenance.source == "Sprite Fright (2021), Blender Studio")
        #expect(reading.pack.provenance.rights?.hasPrefix("CC BY 4.0") == true)
    }
}
