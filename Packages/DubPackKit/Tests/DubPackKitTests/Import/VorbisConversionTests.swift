//
//  VorbisConversionTests.swift
//  DubPackKitTests
//
//  Ogg Vorbis recordings come in as AAC
//

import AVFoundation
import Foundation
import Testing
@testable import DubPackKit

@Suite("Vorbis conversion")
struct VorbisConversionTests {

    @Test func convertsAVorbisFileToADecodableAAC() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("line.m4a")

        try AudioTrackConverter.convert(Fixtures.url("line.ogg"), to: destination)

        let duration = try #require(AVFoundationMediaProbe().audioDuration(of: destination))
        #expect(abs(duration - 0.5) < 0.1)
    }

    @Test func refusesAFileThatIsNotVorbis() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }

        #expect(throws: AudioConversionFailure.notVorbis) {
            try AudioTrackConverter.convert(Fixtures.url("line.mp3"), to: temp.appending("out.m4a"))
        }
    }

    @Test func aPackWithVorbisLinesAndBedInstallsWhole() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.appending("source"), named: "Vorbis Scene")
        try pack.packInfo(["title=\"Vorbis Scene\""])
        try pack.entry("001_Hero", ["caption=\"one\"", "dub_timestamps=[0]"])
        try pack.copyFixture("line.ogg", as: "001_Hero.ogg")
        try pack.entry("002_Hero", ["caption=\"two\"", "dub_timestamps=[2]", "audio=\"002_Hero.ogg\""])
        try pack.copyFixture("line.ogg", as: "002_Hero.ogg")
        try pack.copyFixture("line.ogg", as: "_backing_track.ogg")
        try pack.still("001_Hero.jpg")

        let reporter = RecordingIssueReporter()
        let installed = try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter)
            .install(from: pack.directory)

        #expect(installed.pack.lines.count == 2)
        #expect(installed.pack.lines.map(\.referenceAudioFile) == ["001_Hero.m4a", "002_Hero.m4a"])
        #expect(installed.pack.backingTrackFile == "_backing_track.m4a")
        #expect(installed.issues.filter { if case .missingStill = $0 { false } else { true } }.isEmpty)
        #expect(reporter.breadcrumbs.contains("dub_pack.import converted 3 vorbis files"))

        let files = try FileManager.default.contentsOfDirectory(atPath: installed.directory.path)
        #expect(!files.contains { $0.hasSuffix(".ogg") })
    }

    @Test func aTheoraOnlyOggIsLeftForTheVideoConverter() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "theora-ogg")
        try pack.copyFixture("test.ogv", as: "dub_video.ogg")
        try pack.line("001_A", at: 0)

        let outcome = AudioTrackConverter.convertIfNeeded(in: pack.directory)

        #expect(outcome == AudioTrackConverter.Outcome())
        #expect(FileManager.default.fileExists(atPath: pack.directory.appendingPathComponent("dub_video.ogg").path))
    }

    @Test func repairConvertsWhatAnEarlierInstallLeft() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "installed")
        try pack.packInfo()
        try pack.entry("001_A", ["dub_timestamps=[0]"])
        try pack.copyFixture("line.ogg", as: "001_A.ogg")

        #expect(DubPackRepair.hasPendingConversions(in: pack.directory))
        let issues = await DubPackRepair.convertPending(in: pack.directory)
        #expect(issues.isEmpty)
        #expect(!DubPackRepair.hasPendingConversions(in: pack.directory))

        let reading = try await DubPackReader.testing().read(at: pack.directory)
        #expect(reading.pack.lines.map(\.referenceAudioFile) == ["001_A.m4a"])
    }
}
