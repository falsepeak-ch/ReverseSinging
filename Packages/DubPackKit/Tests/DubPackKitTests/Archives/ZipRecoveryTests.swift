//
//  ZipRecoveryTests.swift
//  DubPackKitTests
//
//  Reading zips whose index is missing, the way a cut-off download leaves them
//

import Foundation
import Testing
import ZIPFoundation
@testable import DubPackKit

@Suite("Zip recovery")
struct ZipRecoveryTests {

    private static let packFiles = [
        "01_Hero.ini", "01_Hero.jpg", "01_Hero.mp3",
        "01_Sidekick.ini", "01_Sidekick.mp3", "01_Sidekick.png",
        "_backing_track.mp3", "icon.jpg",
    ]

    private func streamed() throws -> Data {
        try Data(contentsOf: Fixtures.url("pack_streamed.zip"))
    }

    private func write(_ data: Data, named name: String, in temp: TemporaryDirectory) throws -> URL {
        let url = temp.appending(name)
        try data.write(to: url)
        return url
    }

    private func packFiles(in destination: URL) -> [String] {
        let pack = destination.appendingPathComponent("Streamed Pack")
        return ((try? FileManager.default.contentsOfDirectory(atPath: pack.path)) ?? []).sorted()
    }

    // MARK: - Recovering

    /// The streamed fixture writes every size after its data, stored entries included, which is
    /// the hardest shape to walk without an index.
    @Test func recoversEveryEntryFromAZipWithoutItsIndex() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try write(ZipBytes.withoutIndex(streamed()), named: "no-index.zip", in: temp)
        let destination = temp.appending("out")

        let summary = try ZipRecoveryExtractor.extract(archive, to: destination)

        #expect(packFiles(in: destination) == Self.packFiles)
        #expect(summary.recovery == ArchiveRecovery(indexMissing: true, truncatedEntry: nil, partialKept: false, damagedEntries: 0))
        let recording = try Data(contentsOf: destination.appendingPathComponent("Streamed Pack/01_Hero.mp3"))
        #expect(recording == (try Data(contentsOf: Fixtures.url("line.mp3"))))
    }

    @Test func readsAZipZIPFoundationOpensWithoutRecovering() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.appending("source"), named: "Streamed Pack")
        try pack.line("01_Hero", at: 0.5)
        let archive = temp.appending("plain.zip")
        try FileManager.default.zipItem(at: pack.directory, to: archive, shouldKeepParent: true)
        let destination = temp.appending("out")

        let summary = try ZipExtractor.extract(archive, to: destination)

        #expect(summary.recovery == nil)
        #expect(packFiles(in: destination) == ["01_Hero.jpg", "01_Hero.txt", "01_Hero.wav"])
    }

    /// The streamed fixture's folder entry has no permission bits, as zips written by scripts often
    /// do. ZIPFoundation creates that folder unwritable and gives up; recovery reads it whole, and
    /// since nothing was lost there is nothing to report.
    @Test func readsAZipWhoseFolderEntryHasNoPermissions() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("out")

        let summary = try ZipExtractor.extract(Fixtures.url("pack_streamed.zip"), to: destination)

        #expect(summary.recovery?.isDegraded == false)
        #expect(packFiles(in: destination) == Self.packFiles)
    }

    @Test func fallsBackToRecoveryWhenTheIndexIsGone() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try write(ZipBytes.withoutIndex(streamed()), named: "no-index.zip", in: temp)
        let destination = temp.appending("out")

        let summary = try ZipExtractor.extract(archive, to: destination)

        #expect(summary.recovery?.indexMissing == true)
        #expect(packFiles(in: destination) == Self.packFiles)
    }

    // MARK: - Cut Off

    /// A recording cut short still plays for as long as it goes, so it is kept.
    @Test func keepsARecordingTheEndCutThrough() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let whole = try streamed()
        let archive = try write(ZipBytes.cut(whole, insideEntryEndingWith: "_backing_track.mp3"), named: "cut.zip", in: temp)
        let destination = temp.appending("out")

        let summary = try ZipRecoveryExtractor.extract(archive, to: destination)

        #expect(summary.recovery == ArchiveRecovery(
            indexMissing: true,
            truncatedEntry: "Streamed Pack/_backing_track.mp3",
            partialKept: true,
            damagedEntries: 0
        ))
        #expect(packFiles(in: destination) == Self.packFiles)

        let intact = temp.appending("intact")
        _ = try ZipExtractor.extract(Fixtures.url("pack_streamed.zip"), to: intact)
        let partialSize = try FileManager.default.attributesOfItem(atPath: destination.appendingPathComponent("Streamed Pack/_backing_track.mp3").path)[.size] as? Int
        let wholeSize = try FileManager.default.attributesOfItem(atPath: intact.appendingPathComponent("Streamed Pack/_backing_track.mp3").path)[.size] as? Int
        #expect((partialSize ?? 0) > 0)
        #expect((partialSize ?? 0) < (wholeSize ?? 0))
    }

    /// Half a picture is worse than none: the reader borrows another still instead.
    @Test func dropsAStillTheEndCutThrough() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try write(ZipBytes.cut(streamed(), insideEntryEndingWith: "icon.jpg"), named: "cut.zip", in: temp)
        let destination = temp.appending("out")

        let summary = try ZipRecoveryExtractor.extract(archive, to: destination)

        #expect(summary.recovery?.truncatedEntry == "Streamed Pack/icon.jpg")
        #expect(summary.recovery?.partialKept == false)
        #expect(packFiles(in: destination) == Self.packFiles.filter { $0 != "icon.jpg" && $0 != "_backing_track.mp3" })
    }

    @Test(arguments: [
        ("Streamed Pack/_backing_track.mp3", true),
        ("01_Hero.wav", true),
        ("01_Hero.M4A", true),
        ("dub_video.ogg", false),
        ("dub_video.ogv", false),
        ("icon.jpg", false),
        ("01_Hero.ini", false),
    ])
    func keepsOnlyPartialAudio(path: String, kept: Bool) {
        #expect(ZipRecoveryExtractor.keepsPartial(path) == kept)
    }

    // MARK: - Damage

    @Test func leavesOutAnEntryThatFailsItsChecksum() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let damaged = try ZipBytes.corrupting(ZipBytes.withoutIndex(streamed()), entryEndingWith: "01_Hero.mp3")
        let archive = try write(damaged, named: "damaged.zip", in: temp)
        let destination = temp.appending("out")

        let summary = try ZipRecoveryExtractor.extract(archive, to: destination)

        #expect(summary.recovery?.damagedEntries == 1)
        #expect(packFiles(in: destination) == Self.packFiles.filter { $0 != "01_Hero.mp3" })
    }

    /// With its index intact ZIPFoundation refuses the whole archive over one bad entry; recovery
    /// keeps everything else.
    @Test func keepsTheRestOfAnIndexedZipWithOneDamagedEntry() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try write(ZipBytes.corrupting(streamed(), entryEndingWith: "01_Hero.mp3"), named: "damaged.zip", in: temp)
        let destination = temp.appending("out")

        let summary = try ZipExtractor.extract(archive, to: destination)

        #expect(summary.recovery == ArchiveRecovery(indexMissing: false, truncatedEntry: nil, partialKept: false, damagedEntries: 1))
        #expect(packFiles(in: destination) == Self.packFiles.filter { $0 != "01_Hero.mp3" })
    }

    @Test func refusesEntriesThatClimbOutOfThePack() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("out")

        let summary = try ZipExtractor.extract(Fixtures.url("pack_streamed_unsafe.zip"), to: destination)

        #expect(summary.skippedEntries == 1)
        #expect(!FileManager.default.fileExists(atPath: temp.appending("escape.txt").path))
        #expect(packFiles(in: destination) == Self.packFiles)
    }

    // MARK: - Refusals

    @Test func refusesEncryptedEntries() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let encrypted = try ZipBytes.setting(ZipBytes.withoutIndex(streamed()), field: 6, to: 0x0009, entryEndingWith: "01_Hero.ini")
        let archive = try write(encrypted, named: "locked.zip", in: temp)

        #expect(throws: ExtractionError.failed(.encrypted)) {
            try ZipRecoveryExtractor.extract(archive, to: temp.appending("out"))
        }
    }

    @Test func refusesACompressionMethodItDoesNotHave() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let bzipped = try ZipBytes.setting(ZipBytes.withoutIndex(streamed()), field: 8, to: 12, entryEndingWith: "01_Hero.ini")
        let archive = try write(bzipped, named: "bzip2.zip", in: temp)

        #expect {
            try ZipRecoveryExtractor.extract(archive, to: temp.appending("out"))
        } throws: { error in
            guard case .failed(.unsupportedMethod) = error as? ExtractionError else { return false }
            return true
        }
    }

    @Test func refusesAFileThatIsNotAZip() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try write(Data(repeating: 0x41, count: 512), named: "text.zip", in: temp)

        #expect(throws: ExtractionError.failed(.notAnArchive)) {
            try ZipRecoveryExtractor.extract(archive, to: temp.appending("out"))
        }
    }

    /// When neither reader can make anything of it, the zip is reported as damaged.
    @Test func reportsAHopelessZipAsCorrupt() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try write(Data([0x50, 0x4B, 0x03, 0x04]) + Data(repeating: 0xFF, count: 40), named: "hopeless.zip", in: temp)

        #expect {
            try ZipExtractor.extract(archive, to: temp.appending("out"))
        } throws: { error in
            guard case .failed(.corrupt) = error as? ExtractionError else { return false }
            return true
        }
    }
}
