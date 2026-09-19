//
//  PackDirectoryTests.swift
//  DubPackKitTests
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("Pack directory")
struct PackDirectoryTests {

    @Test func findsFilesRegardlessOfCase() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.still("001_Hero.jpg")

        let folder = try #require(PackDirectory(url: pack.directory))

        #expect(folder.file(named: "001_HERO.JPG")?.name == "001_Hero.jpg")
        #expect(folder.file(stem: "001_hero", extensions: ["png", "jpg"])?.name == "001_Hero.jpg")
    }

    /// Archives made on different systems store accented names decomposed or composed.
    @Test func findsFilesRegardlessOfUnicodeNormalisation() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.still("01_Andre\u{0301}.png")

        let folder = try #require(PackDirectory(url: pack.directory))

        #expect(folder.file(named: "01_Andr\u{00E9}.png") != nil)
    }

    @Test func findsANestedAssetByItsPathOrItsName() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write(Data([0xFF]), to: "stills/001.png")
        try pack.still("002.jpg")

        let folder = try #require(PackDirectory(url: pack.directory))

        #expect(folder.file(named: "stills/001.png")?.name == "stills/001.png")
        #expect(folder.file(named: "shots\\002.jpg")?.name == "002.jpg")
        #expect(folder.file(named: "../outside.png") == nil)
    }

    @Test func entriesExcludeThePackInfoAndUnderscoredNotes() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.packInfo(named: "pack_info.txt")
        try pack.write("note", to: "_notes.txt")
        try pack.write("x", to: "001_Hero.txt")
        try pack.write("x", to: "002_Hero.ini")
        try pack.write("x", to: "readme.txt")

        let folder = try #require(PackDirectory(url: pack.directory))

        #expect(folder.packInfoFile?.name == "pack_info.txt")
        #expect(folder.entryCandidates.map(\.name) == ["001_Hero.txt", "002_Hero.ini", "readme.txt"])
        #expect(folder.numberedEntryCount == 2)
    }

    /// Two copies of one entry would be two lines with one slug, and the takes would collide.
    @Test func prefersTheTxtEntryWhenBothExtensionsExist() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write("x", to: "001_Hero.ini")
        try pack.write("x", to: "001_Hero.txt")

        #expect(PackDirectory(url: pack.directory)?.entryCandidates.map(\.name) == ["001_Hero.txt"])
    }

    @Test func countsFilesByExtension() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write("x", to: "01_A.ini")
        try pack.write("x", to: "01_B.INI")
        try pack.still("01_A.jpg")
        try pack.write("x", to: "README")

        #expect(PackDirectory(url: pack.directory)?.fileTypeCounts == ["ini": 2, "jpg": 1, "": 1])
    }

    @Test func findsTheSceneVideoByNameThenByBeingTheOnlyOne() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        func sceneVideo() -> [String] { names(PackDirectory(url: pack.directory)?.sceneVideo) }

        try pack.write(Data(), to: "clip.mp4")
        #expect(sceneVideo() == ["clip.mp4"])

        try pack.write(Data(), to: "outtake.mov")
        #expect(sceneVideo() == ["clip.mp4", "outtake.mov"], "two unnamed videos are ambiguous")

        try pack.write(Data(), to: "dub_video.ogv")
        #expect(sceneVideo() == ["dub_video.ogv"], "the named video wins")
    }

    /// `.ogg` is as often a Vorbis bed as a Theora scene, so only its name makes it a video.
    @Test func anUnnamedOggIsNeverTheSceneVideo() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write(Data(), to: "_backing_track.ogg")
        try pack.write(Data(), to: "dub_video.ogg")

        let folder = try #require(PackDirectory(url: pack.directory))

        #expect(names(folder.sceneVideo) == ["dub_video.ogg"])
        #expect(names(folder.backingTrack(claimedNames: [])) == ["_backing_track.ogg"])
    }

    @Test func aFileNamedLikeTheSceneIsNeverTheBackingTrack() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write(Data(), to: "dub_video.ogg")

        #expect(PackDirectory(url: pack.directory)?.backingTrack(claimedNames: []) == .notFound)
    }

    private func names(_ match: PackDirectory.Match?) -> [String] {
        switch match {
        case .found(let file): [file.name]
        case .ambiguous(let files): files.map(\.name)
        case .notFound, nil: []
        }
    }

    @Test func aBackingTrackIsNeverALineOrANumberedFile() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url)
        try pack.write(Data(), to: "001_Hero.wav")
        try pack.write(Data(), to: "take.wav")
        try pack.write(Data(), to: "music.mp3")

        let folder = try #require(PackDirectory(url: pack.directory))

        guard case .found(let track) = folder.backingTrack(claimedNames: ["take.wav"]) else {
            Issue.record("music.mp3 is the only unclaimed, unnumbered audio")
            return
        }
        #expect(track.name == "music.mp3")
    }
}
