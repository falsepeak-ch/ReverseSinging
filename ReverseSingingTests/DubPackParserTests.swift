//
//  DubPackParserTests.swift
//  ReverseSingingTests
//
//  Parsing the community dub-pack format
//

import Testing
import Foundation
import AVFoundation
import CoreGraphics
@testable import ReverseSinging

// MARK: - Fixture

/// Builds a miniature pack on disk mirroring the real format, including wavs of known
/// length so the parser has real durations to measure.
private struct DubPackFixture {
    let directory: URL

    init(includePackInfo: Bool = true, includeBackingTrack: Bool = true) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dubfixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if includePackInfo {
            try write("""
            [data]

            title="Harry meets dobby full scene harry potter dub pack"
            icon="001_Dobby.jpg"
            authors=["Hollyfrogg"]
            """, to: DubPackParser.packInfoFilename)
        }

        try addLine(
            slug: "001_Dobby",
            caption: "*Shrieking with joy*",
            character: "Dobby",
            timestamp: 0.000,
            audioDuration: 1.0
        )

        // The caption here contains a comma — it must survive intact
        try addLine(
            slug: "005_Harry",
            caption: "not to be rude or anything, but this isn't a great time for me to have a house elf in my bedroom.",
            character: "Harry",
            timestamp: 18.334,
            audioDuration: 2.0
        )

        // Underscored filename, spaced character name
        try addLine(
            slug: "018_Mr_Dursley",
            caption: "Oh! Don't mind that, it's just the cat.",
            character: "Mr Dursley",
            timestamp: 78.306,
            audioDuration: 1.5
        )

        if includeBackingTrack {
            try writeSilentWav(named: "\(DubPackParser.backingTrackPrefix).wav", duration: 90)
        }
    }

    func addLine(
        slug: String,
        caption: String,
        character: String,
        timestamp: Double,
        audioDuration: Double
    ) throws {
        try write("""
        [data]

        caption="\(caption)"
        image="\(slug).jpg"
        dub_timestamps=[\(String(format: "%.3f", timestamp))]
        dub_characters=["\(character)"]
        """, to: "\(slug).txt")

        try Data([0xFF, 0xD8, 0xFF]).write(to: directory.appendingPathComponent("\(slug).jpg"))
        try writeSilentWav(named: "\(slug).wav", duration: audioDuration)
    }

    func write(_ contents: String, to name: String) throws {
        try contents.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    /// A real 48 kHz mono PCM file, matching what a pack ships.
    func writeSilentWav(named name: String, duration: Double) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!

        let url = directory.appendingPathComponent(name)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        try file.write(from: buffer)
    }

    /// A real, decodable H.264 file under the pack's video name.
    func writeVideo(named name: String, duration: Double = 1.0) throws {
        let url = directory.appendingPathComponent(name)
        let size = CGSize(width: 64, height: 48)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 10
        for frame in 0..<Int(duration * Double(fps)) {
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool!, &pixelBuffer)
            guard let pixelBuffer else { continue }
            while !input.isReadyForMoreMediaData { usleep(1000) }
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }

        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
    }

    func remove(_ name: String) throws {
        try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}

// MARK: - Key/Value Parsing

@Suite("Dub Pack Key/Value Parsing")
struct DubPackKeyValueTests {

    @Test func parsesQuotedScalars() {
        let fields = DubPackParser.parseKeyValues("""
        [data]

        title="Harry meets dobby"
        icon="001_Dobby.jpg"
        """)

        #expect(fields["title"]?.stringValue == "Harry meets dobby")
        #expect(fields["icon"]?.stringValue == "001_Dobby.jpg")
    }

    @Test func keepsCommasInsideCaptions() {
        let caption = "not to be rude or anything, but this isn't a great time"
        let fields = DubPackParser.parseKeyValues("caption=\"\(caption)\"")

        #expect(fields["caption"]?.stringValue == caption)
    }

    @Test func parsesArrays() {
        let fields = DubPackParser.parseKeyValues("""
        dub_timestamps=[0.000]
        dub_characters=["Mr Dursley"]
        authors=["Hollyfrogg", "Someone Else"]
        """)

        #expect(fields["dub_timestamps"]?.arrayValue == ["0.000"])
        #expect(fields["dub_characters"]?.arrayValue == ["Mr Dursley"])
        #expect(fields["authors"]?.arrayValue == ["Hollyfrogg", "Someone Else"])
    }

    @Test func parsesMultiElementArraysTheFormatAllows() {
        let fields = DubPackParser.parseKeyValues("""
        dub_timestamps=[1.5, 9.25]
        dub_characters=["Harry", "Ron"]
        """)

        #expect(fields["dub_timestamps"]?.arrayValue == ["1.5", "9.25"])
        #expect(fields["dub_characters"]?.arrayValue == ["Harry", "Ron"])
    }

    @Test func splitsOnFirstEqualsOnly() {
        let fields = DubPackParser.parseKeyValues("caption=\"x = y, and z = w\"")

        #expect(fields["caption"]?.stringValue == "x = y, and z = w")
    }

    @Test func ignoresSectionHeadersAndBlankLines() {
        let fields = DubPackParser.parseKeyValues("""
        [data]

        title="Something"

        """)

        #expect(fields.count == 1)
    }

    @Test func unescapesQuotesInsideValues() {
        let fields = DubPackParser.parseKeyValues(#"caption="he said \"hello\" loudly""#)

        #expect(fields["caption"]?.stringValue == #"he said "hello" loudly"#)
    }
}

// MARK: - Pack Parsing

@Suite("Dub Pack Parsing")
struct DubPackParsingTests {

    @Test func parsesPackMetadata() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(pack.title == "Harry meets dobby full scene harry potter dub pack")
        #expect(pack.authors == ["Hollyfrogg"])
        #expect(pack.iconFile == "001_Dobby.jpg")
        #expect(pack.folderName == "harry-dobby")
        #expect(pack.backingTrackFile == "\(DubPackParser.backingTrackPrefix).wav")
        #expect(pack.lines.count == 3)
    }

    @Test func readsTimestampsAndOrdersLines() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(pack.lines[0].startTime == 0.000)
        #expect(pack.lines[1].startTime == 18.334)
        #expect(pack.lines[2].startTime == 78.306)
        #expect(pack.lines.map(\.index) == [1, 5, 18])
    }

    @Test func measuresLineDurationFromTheReferenceWav() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(abs(pack.lines[0].duration - 1.0) < 0.01)
        #expect(abs(pack.lines[1].duration - 2.0) < 0.01)
        #expect(abs(pack.lines[1].endTime - 20.334) < 0.01)
    }

    @Test func keepsCaptionPunctuationIntact() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(pack.lines[1].caption.contains("not to be rude or anything, but"))
        #expect(pack.lines[1].caption.hasSuffix("in my bedroom."))
    }

    @Test func readsSpacedCharacterNamesFromUnderscoredFilenames() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(pack.lines[2].slug == "018_Mr_Dursley")
        #expect(pack.lines[2].character == "Mr Dursley")
    }

    @Test func fallsBackToTheFilenameWhenCharacterIsMissing() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        try fixture.write("""
        [data]

        caption="No character listed"
        image="020_Aunt_Petunia.jpg"
        dub_timestamps=[95.0]
        """, to: "020_Aunt_Petunia.txt")
        try Data([0xFF, 0xD8, 0xFF]).write(to: fixture.directory.appendingPathComponent("020_Aunt_Petunia.jpg"))
        try fixture.writeSilentWav(named: "020_Aunt_Petunia.wav", duration: 1.0)

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(pack.lines.last?.character == "Aunt Petunia")
    }

    @Test func listsCharactersInOrderOfFirstAppearance() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(pack.characters == ["Dobby", "Harry", "Mr Dursley"])
    }

    @Test func usesBackingTrackDurationForThePack() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(abs(pack.duration - 90) < 0.1)
    }

    @Test func fallsBackToTheLastLineWhenThereIsNoBackingTrack() throws {
        let fixture = try DubPackFixture(includeBackingTrack: false)
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")

        #expect(pack.backingTrackFile == nil)
        #expect(abs(pack.duration - (78.306 + 1.5)) < 0.05)
    }

    @Test func findsAPlayableSceneVideo() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        try fixture.writeVideo(named: "\(DubPackParser.videoPrefix).mp4")

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "Scene")

        #expect(pack.videoFile == "\(DubPackParser.videoPrefix).mp4")
        #expect(pack.videoURL != nil)
    }

    @Test func hasNoVideoWhenThePackShipsNone() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "Scene")

        #expect(pack.videoFile == nil)
        #expect(pack.videoURL == nil)
    }

    /// Theora parses as a file but AVFoundation cannot decode it, and recording it as the
    /// video would leave every dub screen showing a black rectangle.
    @Test func ignoresAVideoInAFormatThatCannotBeDecoded() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        try Data(count: 4096).write(
            to: fixture.directory.appendingPathComponent("\(DubPackParser.videoPrefix).ogv")
        )

        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "Scene")

        #expect(pack.videoFile == nil)
    }

    @Test func rejectsAFolderThatIsNotAPack() throws {
        let fixture = try DubPackFixture(includePackInfo: false)
        defer { fixture.cleanup() }

        #expect(throws: DubPackError.self) {
            try DubPackParser.parsePack(at: fixture.directory, folderName: "not-a-pack")
        }
    }

    @Test func reportsTheMissingAssetByName() throws {
        let fixture = try DubPackFixture()
        defer { fixture.cleanup() }

        try fixture.remove("005_Harry.wav")

        #expect(throws: DubPackError.self) {
            try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")
        }
    }
}

// MARK: - Timeline Lookup

@Suite("Dub Timeline Lookup")
struct DubTimelineTests {

    private func makePack() throws -> (DubPack, DubPackFixture) {
        let fixture = try DubPackFixture()
        let pack = try DubPackParser.parsePack(at: fixture.directory, folderName: "harry-dobby")
        return (pack, fixture)
    }

    @Test func findsTheLinePlayingAtATime() throws {
        let (pack, fixture) = try makePack()
        defer { fixture.cleanup() }

        #expect(pack.line(at: 0.0)?.slug == "001_Dobby")
        #expect(pack.line(at: 18.5)?.slug == "005_Harry")
        #expect(pack.line(at: 100.0)?.slug == "018_Mr_Dursley")
    }

    @Test func holdsThePreviousLineThroughGaps() throws {
        let (pack, fixture) = try makePack()
        defer { fixture.cleanup() }

        // 10s is past line 1's end but before line 5 starts
        #expect(pack.line(at: 10.0)?.slug == "001_Dobby")
    }

    @Test func clampsBeforeTheFirstLine() throws {
        let (pack, fixture) = try makePack()
        defer { fixture.cleanup() }

        #expect(pack.line(at: -5)?.slug == "001_Dobby")
    }
}
