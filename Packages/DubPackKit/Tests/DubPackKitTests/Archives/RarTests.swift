//
//  RarTests.swift
//  DubPackKitTests
//
//  RAR archives, which pack authors make as often as 7z and then rename `.zip`
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("RAR extractor")
struct RarExtractorTests {

    private static let packFiles = [
        "001_Hero.jpg", "001_Hero.txt", "001_Hero.wav",
        "002_Hero.mp3", "002_Hero.png", "002_Hero.txt",
        "_backing_track.mp3", "_pack_info.ini",
    ]

    @Test func recognisesARarByItsBytesWhateverItIsCalled() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let renamed = temp.appending("scene.zip")
        try FileManager.default.copyItem(at: Fixtures.url("pack_store.rar"), to: renamed)

        #expect(ArchiveKind.detect(at: renamed) == .rar)
        #expect(ArchiveKind.detect(at: try Fixtures.url("pack_store.rar")) == .rar)

        // RAR 1.5 to 4 carries a different seventh byte.
        let rar4 = temp.appending("old.bin")
        try Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00, 0x00]).write(to: rar4)
        #expect(ArchiveKind.detect(at: rar4) == .rar)
    }

    @Test func unpacksEveryEntryIntact() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("out")

        let summary = try RarExtractor.extract(Fixtures.url("pack_store.rar"), to: destination)

        let folder = destination.appendingPathComponent("Fixture Pack")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(files == Self.packFiles)
        #expect(summary == ExtractionSummary(skippedEntries: 0))

        // Byte for byte what the 7z fixture of the same pack unpacks to.
        let reference = temp.appending("reference")
        _ = try SevenZipExtractor.extract(Fixtures.url("pack_store.7z"), to: reference)
        for file in Self.packFiles {
            let unpacked = try Data(contentsOf: folder.appendingPathComponent(file))
            let expected = try Data(contentsOf: reference.appendingPathComponent("Fixture Pack/\(file)"))
            #expect(unpacked == expected, "\(file) differs")
        }
    }

    @Test func reportsProgressUpToCompletion() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let fractions = Fractions()

        _ = try RarExtractor.extract(Fixtures.url("pack_store.rar"), to: temp.appending("out")) { fractions.append($0) }

        #expect(fractions.values.last == 1)
        #expect(fractions.values == fractions.values.sorted())
    }

    @Test func refusesEntriesThatClimbOutOfTheDestination() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("nested/out")

        let summary = try RarExtractor.extract(Fixtures.url("pack_unsafe_path.rar"), to: destination)

        #expect(summary.skippedEntries == 1)
        #expect(!FileManager.default.fileExists(atPath: temp.appending("nested/evil.txt").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Fixture Pack/ok.txt").path))
    }

    /// A download that stopped short keeps every entry before the break, as a cut-off zip does.
    @Test func keepsWhatCameOutWholeFromACutOffArchive() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let whole = try Data(contentsOf: Fixtures.url("pack_store.rar"))
        let cut = temp.appending("cut.rar")
        // Partway through `001_Hero.wav`, the third and by far the largest entry.
        try whole.prefix(20_000).write(to: cut)

        let summary = try RarExtractor.extract(cut, to: temp.appending("out"))

        let files = try FileManager.default.contentsOfDirectory(atPath: temp.appending("out/Fixture Pack").path).sorted()
        #expect(files == ["001_Hero.jpg", "001_Hero.txt"])
        let recovery = try #require(summary.recovery)
        #expect(recovery.isDegraded)
        #expect(recovery.truncatedEntry == "Fixture Pack/001_Hero.wav")
        #expect(!recovery.partialKept)
    }

    @Test func refusesAnArchiveWithNothingReadableInIt() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let stub = temp.appending("stub.rar")
        try Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00, 0xFF, 0xFF, 0xFF]).write(to: stub)

        #expect(throws: ExtractionError.self) {
            try RarExtractor.extract(stub, to: temp.appending("out"))
        }
    }

    @Test func refusesAFileThatIsNotARar() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }

        #expect(throws: ExtractionError.failed(.notAnArchive)) {
            try RarExtractor.extract(Fixtures.url("pack_store.7z"), to: temp.appending("out"))
        }
    }
}

@Suite("Installer: RAR")
struct RarInstallTests {

    @Test(arguments: ["Fixture Pack.rar", "fixture_pack_renamed.zip"])
    func installsARarUnderAnyName(name: String) async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = temp.appending(name)
        try FileManager.default.copyItem(at: Fixtures.url("pack_store.rar"), to: archive)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.pack.title == "Fixture Pack")
        #expect(installed.pack.lines.map(\.referenceAudioFile) == ["001_Hero.wav", "002_Hero.mp3"])
        #expect(installed.pack.backingTrackFile == "_backing_track.mp3")
        #expect(installed.issues.isEmpty)
    }

    @Test func aCutOffRarInstallsWhatItCanAndSaysSo() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let whole = try Data(contentsOf: Fixtures.url("pack_store.rar"))
        let cut = temp.appending("Fixture Pack.rar")
        // Through the first line and into the second's recording; the pack info never arrives.
        try whole.prefix(60_000).write(to: cut)
        let reporter = RecordingIssueReporter()

        let installed = try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: cut)

        #expect(installed.pack.lines.map(\.slug) == ["001_Hero"])
        #expect(reporter.kinds.contains(.recoveredArchive))
    }
}

/// Collects progress fractions from the extractor's callback, which arrives on its thread.
private final class Fractions: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Double] = []

    func append(_ value: Double) { lock.withLock { stored.append(value) } }
    var values: [Double] { lock.withLock { stored } }
}
