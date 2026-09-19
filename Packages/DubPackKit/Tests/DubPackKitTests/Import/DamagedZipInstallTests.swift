//
//  DamagedZipInstallTests.swift
//  DubPackKitTests
//
//  Installing the packs that arrive broken: cut off, without pack info, wrapped in a folder
//

import Foundation
import Testing
import ZIPFoundation
@testable import DubPackKit

@Suite("Installer: damaged and unusual zips")
struct DamagedZipInstallTests {

    private func cutStreamedZip(named name: String, in temp: TemporaryDirectory) throws -> URL {
        let whole = try Data(contentsOf: Fixtures.url("pack_streamed.zip"))
        let archive = temp.appending(name)
        try ZipBytes.cut(whole, insideEntryEndingWith: "_backing_track.mp3").write(to: archive)
        return archive
    }

    /// The Forrest Gump pack's shape: a download cut off inside the backing track, `.ini` line
    /// entries, two characters sharing a number, no pack info, all wrapped in a folder.
    @Test func installsAPackFromAZipThatWasCutOff() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try cutStreamedZip(named: "streamed_pack.zip", in: temp)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.folderName == "streamed_pack")
        #expect(installed.pack.title == "Streamed Pack", "titled after the folder it came wrapped in")
        #expect(installed.pack.lines.map(\.character) == ["Hero", "Sidekick"])
        #expect(installed.pack.lines.map(\.imageFile) == ["01_Hero.jpg", "01_Sidekick.png"])
        #expect(installed.pack.iconFile == "icon.jpg")
        #expect(installed.pack.backingTrackFile == "_backing_track.mp3", "the partial bed still plays")
        #expect(installed.issues == [
            .archiveRecovered(truncatedEntry: "_backing_track.mp3", partialKept: true, damagedEntries: 0),
            .missingPackInfo(otherTextFiles: []),
        ])
    }

    @Test func titlesAWrappedPackAfterItsFolderAndAFlatOneAfterItsArchive() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.appending("source"), named: "Forrest Gump - Forrest Proposes to Jenny")
        try pack.line("01_Forrest", at: 0.96, character: "Forrest")

        let wrapped = temp.appending("forrest_gump_-_forrest_proposes_to_jenny.zip")
        let flat = temp.appending("flat_scene.zip")
        try FileManager.default.zipItem(at: pack.directory, to: wrapped, shouldKeepParent: true)
        try FileManager.default.zipItem(at: pack.directory, to: flat, shouldKeepParent: false)
        let installer = DubPackInstaller.testing(library: temp.appending("library"))

        let fromWrapped = try await installer.install(from: wrapped)
        let fromFlat = try await installer.install(from: flat)

        #expect(fromWrapped.pack.title == "Forrest Gump - Forrest Proposes to Jenny")
        #expect(fromWrapped.folderName == "forrest_gump_-_forrest_proposes_to_jenny")
        #expect(fromFlat.pack.title == "flat_scene")
    }

    @Test func pointsAtTheRecoveryInCrashReports() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let archive = try cutStreamedZip(named: "streamed_pack.zip", in: temp)

        _ = try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: archive)

        #expect(reporter.kinds == [.missingPackInfo, .recoveredArchive])
        let report = try #require(reporter.report(.recoveredArchive))
        #expect(report.context == "dub_pack.recovered_archive")
        #expect(report.keys["pack_title"] == .string("Streamed Pack"))
        #expect(report.keys["truncated_entry"] == .string("_backing_track.mp3"))
        #expect(report.keys["partial_kept"] == .bool(true))
        #expect(report.keys["damaged_count"] == .int(0))
    }

    /// A folder with no pack in it used to fail with nothing attached to say why.
    @Test func aFolderWithNoPackInItSaysWhatItHolds() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let photos = try PackBuilder(in: temp.url, named: "Holiday Photos")
        try photos.still("IMG_0001.jpg")
        try photos.still("IMG_0002.jpg")
        try photos.write("notes", to: "Itinerary.pdf")

        await #expect(throws: DubPackImportError.noPackFound) {
            try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: photos.directory)
        }

        #expect(reporter.kinds == [.noLineEntries, .importFailed])
        let report = try #require(reporter.report(.noLineEntries))
        #expect(report.keys["file_types"] == .string("jpg: 2, pdf: 1"))
        #expect(report.keys["file_count"] == .int(3))
    }
}
