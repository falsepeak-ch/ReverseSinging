//
//  ArchiveTests.swift
//  DubPackKitTests
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("Archive kind")
struct ArchiveKindTests {

    @Test func tellsArchivesApartByTheirBytesNotTheirNames() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }

        let renamed = temp.appending("definitely-a.zip")
        try FileManager.default.copyItem(at: Fixtures.url("pack_lzma2.7z"), to: renamed)
        #expect(ArchiveKind.detect(at: renamed) == .sevenZip)

        let zip = temp.appending("pack.bin")
        try Data([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]).write(to: zip)
        #expect(ArchiveKind.detect(at: zip) == .zip)

        let tar = temp.appending("pack.7z")
        try Data(count: 512).write(to: tar)
        #expect(ArchiveKind.detect(at: tar) == nil, "a .7z that is not one is not a 7z")
    }
}

@Suite("7z extractor")
struct SevenZipExtractorTests {

    private static let packFiles = [
        "001_Hero.jpg", "001_Hero.txt", "001_Hero.wav",
        "002_Hero.mp3", "002_Hero.png", "002_Hero.txt",
        "_backing_track.mp3", "_pack_info.ini",
    ]

    /// One fixture per method 7-Zip offers for the format. LZMA2 is its default; the rest are
    /// one dropdown away. Deflate and BZip2 go through the system's libz and libbz2.
    @Test(arguments: ["lzma2", "lzma1", "ppmd", "deflate", "bzip2", "store"])
    func unpacksEveryCompressionMethod(method: String) throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }

        let summary = try SevenZipExtractor.extract(Fixtures.url("pack_\(method).7z"), to: temp.url)

        let pack = temp.appending("Fixture Pack")
        #expect(try FileManager.default.contentsOfDirectory(atPath: pack.path).sorted() == Self.packFiles)
        #expect(summary.skippedEntries == 0)

        // Bytes, not just names: the wav is the file big enough to notice damage in.
        let wav = try Data(contentsOf: pack.appendingPathComponent("001_Hero.wav"))
        #expect(wav.count == 57_678)
        #expect(wav.prefix(4) == Data("RIFF".utf8))
    }

    @Test func reportsProgressUpToCompletion() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }

        final class Box: @unchecked Sendable {
            let lock = NSLock()
            var values: [Double] = []
        }
        let box = Box()

        _ = try SevenZipExtractor.extract(Fixtures.url("pack_store.7z"), to: temp.url) { value in
            box.lock.withLock { box.values.append(value) }
        }

        #expect(box.values.last == 1)
        #expect(box.values == box.values.sorted())
    }

    /// `../escape.txt` must not land beside the destination, and must be counted.
    @Test func refusesEntriesThatClimbOutOfTheDestination() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let destination = temp.appending("out")

        let summary = try SevenZipExtractor.extract(Fixtures.url("pack_unsafe_path.7z"), to: destination)

        #expect(summary.skippedEntries == 1)
        #expect(!FileManager.default.fileExists(atPath: temp.appending("escape.txt").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("_pack_info.ini").path))
    }

    @Test func refusesATruncatedArchive() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let whole = try Data(contentsOf: Fixtures.url("pack_lzma2.7z"))
        let cut = temp.appending("cut.7z")
        try whole.prefix(whole.count / 2).write(to: cut)

        #expect {
            try SevenZipExtractor.extract(cut, to: temp.appending("out"))
        } throws: { error in
            guard case .failed(.corrupt) = error as? ExtractionError else { return false }
            return true
        }
    }

    @Test func refusesAFileThatIsNotAnArchive() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = temp.appending("pack.7z")
        try Data(count: 4096).write(to: file)

        #expect(throws: ExtractionError.failed(.notAnArchive)) {
            try SevenZipExtractor.extract(file, to: temp.appending("out"))
        }
    }
}
