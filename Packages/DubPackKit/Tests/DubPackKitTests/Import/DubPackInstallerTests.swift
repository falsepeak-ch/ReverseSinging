//
//  DubPackInstallerTests.swift
//  DubPackKitTests
//

import AVFoundation
import Foundation
import Testing
import ZIPFoundation
@testable import DubPackKit

/// A minimal complete pack called `name`, in its own parent folder under `temp`.
private func makeSource(in temp: TemporaryDirectory, named name: String = "Scene From Files") throws -> PackBuilder {
    let parent = temp.appending("source-\(UUID().uuidString)")
    let pack = try PackBuilder(in: parent, named: name)
    try pack.packInfo(["title=\"Imported Scene\"", "icon=\"001_Hero.jpg\"", "authors=[\"Tester\"]"])
    try pack.line("001_Hero", at: 0, character: "Hero")
    try pack.line("002_Hero", at: 3.5, character: "Hero")
    return pack
}

private func contents(of url: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted()
}

@Suite("Installer")
struct DubPackInstallerTests {

    // MARK: - Sources

    @Test func installsAFolder() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let library = temp.appending("library")
        let source = try makeSource(in: temp)

        let installed = try await DubPackInstaller.testing(library: library).install(from: source.directory)

        #expect(installed.folderName == "Scene From Files")
        #expect(installed.directory.standardizedFileURL == library.appendingPathComponent("Scene From Files").standardizedFileURL)
        #expect(installed.pack.title == "Imported Scene")
        #expect(installed.pack.lines.count == 2)
        #expect(installed.issues.isEmpty)
        #expect(FileManager.default.fileExists(atPath: installed.directory.appendingPathComponent("001_Hero.wav").path))
        #expect(FileManager.default.fileExists(atPath: source.directory.path), "a folder the user chose is copied, never moved")
    }

    @Test func installsAZipWithAWrappingFolder() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let source = try makeSource(in: temp, named: "Zipped Scene")
        let archive = temp.appending("pack.zip")
        try FileManager.default.zipItem(at: source.directory, to: archive, shouldKeepParent: true)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.folderName == "pack")
        #expect(installed.pack.title == "Imported Scene")
        #expect(installed.pack.lines.count == 2)
    }

    @Test func installsAZipWithFilesAtTheRoot() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let source = try makeSource(in: temp)
        let archive = temp.appending("flat.zip")
        try FileManager.default.zipItem(at: source.directory, to: archive, shouldKeepParent: false)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.pack.lines.count == 2)
    }

    @Test func installsAFolderWithoutPackInfoUnderItsOwnName() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let source = try makeSource(in: temp, named: "Unlabelled Scene")
        try source.remove("_pack_info.ini")

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: source.directory)

        #expect(installed.pack.title == "Unlabelled Scene")
        #expect(installed.issues == [.missingPackInfo(otherTextFiles: [])])
    }

    /// A link to a pack folder is the folder. Reading through the link itself lists nothing, and
    /// used to refuse the pack as not being there.
    @Test func installsAFolderReachedThroughASymbolicLink() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let source = try makeSource(in: temp)
        let link = temp.appending("Linked Scene")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source.directory)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: link)

        #expect(installed.folderName == "Linked Scene")
        #expect(installed.pack.title == "Imported Scene")
        #expect(installed.pack.lines.count == 2)
        #expect(installed.issues.isEmpty)
        #expect(FileManager.default.fileExists(atPath: source.directory.appendingPathComponent("001_Hero.wav").path), "the linked folder is copied, never moved")
    }

    // MARK: - Video

    /// Theora is converted during install, and the original, by far the largest file in a pack,
    /// does not survive it.
    @Test func convertsTheSceneVideo() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let source = try makeSource(in: temp)
        try source.copyFixture("test.ogv", as: "dub_video.ogv")

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: source.directory)

        #expect(installed.pack.videoFile == "dub_video.mp4")
        #expect(contents(of: installed.directory).contains("dub_video.mp4"))
        #expect(!contents(of: installed.directory).contains("dub_video.ogv"))

        let asset = AVURLAsset(url: installed.directory.appendingPathComponent("dub_video.mp4"))
        #expect(abs(try await asset.load(.duration).seconds - 9.0) < 0.2)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await track.load(.naturalSize) == CGSize(width: 640, height: 480))
    }

    /// Losing the picture beats losing the scene.
    @Test func stillInstallsWhenTheVideoCannotBeConverted() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let source = try makeSource(in: temp)
        try source.write(Data(count: 4096), to: "dub_video.ogv")

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: source.directory)

        #expect(installed.pack.lines.count == 2)
        #expect(installed.pack.videoFile == nil)
        #expect(installed.issues == [.videoConversionFailed(file: "dub_video.ogv", failure: .notTheora)])
        #expect(!contents(of: installed.directory).contains { $0.hasPrefix("dub_video") })
    }

    // MARK: - Replacing

    @Test func reinstallingReplacesRatherThanDuplicates() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let library = temp.appending("library")
        let source = try makeSource(in: temp)
        let installer = DubPackInstaller.testing(library: library)

        let first = try await installer.install(from: source.directory)
        let second = try await installer.install(from: source.directory)

        #expect(first.folderName == second.folderName)
        #expect(contents(of: library) == ["Scene From Files"])
    }

    /// The takes recorded against a pack live under its identity; a broken re-import must not
    /// cost the user the pack they already had.
    @Test func aFailedReinstallLeavesThePreviousInstallInPlace() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let library = temp.appending("library")
        let installer = DubPackInstaller.testing(library: library)

        let good = try makeSource(in: temp, named: "Scene")
        let installed = try await installer.install(from: good.directory)
        try Data("host cache".utf8).write(to: installed.directory.appendingPathComponent("manifest.json"))

        let broken = try PackBuilder(in: temp.appending("broken"), named: "Scene")
        try broken.packInfo()
        try broken.entry("001_Hero", ["caption=\"never timed\""])

        await #expect(throws: DubPackImportError.noLines(issues: [.droppedLine(file: "001_Hero.txt", reason: .missingTimestamp)])) {
            try await installer.install(from: broken.directory)
        }

        #expect(contents(of: library) == ["Scene"], "no staging folder is left behind")
        #expect(contents(of: installed.directory).contains("manifest.json"))
        #expect(contents(of: installed.directory).contains("002_Hero.wav"))
    }

    @Test func neverCopiesTheHostsIgnoredFiles() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let source = try makeSource(in: temp)
        try source.write("{}", to: "manifest.json")
        try source.write("x", to: "Thumbs.db")

        let installed = try await DubPackInstaller.testing(library: temp.appending("library"), ignoredFileNames: ["manifest.json"])
            .install(from: source.directory)

        #expect(!contents(of: installed.directory).contains("manifest.json"))
        #expect(!contents(of: installed.directory).contains("Thumbs.db"))
    }

    @Test func saysWhereASourceWillInstall() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let library = temp.appending("library")
        let installer = DubPackInstaller.testing(library: library)

        #expect(installer.installLocation(for: URL(fileURLWithPath: "/tmp/Some: Pack.7z")).lastPathComponent == "Some- Pack")
        #expect(installer.installLocation(for: URL(fileURLWithPath: "/tmp/.hidden.zip")).lastPathComponent == "hidden")
        #expect(installer.installLocation(for: temp.url).lastPathComponent == temp.url.lastPathComponent, "a folder keeps its whole name")
    }

    // MARK: - Failures

    @Test func refusesAFolderWithNoPackInIt() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let photos = try PackBuilder(in: temp.url, named: "Holiday Photos")
        try photos.still("IMG_0001.jpg")

        await #expect(throws: DubPackImportError.noPackFound) {
            try await DubPackInstaller.testing(library: temp.appending("library")).install(from: photos.directory)
        }
    }

    @Test func namesAFileTypeItCannotOpen() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let rar = temp.appending("pack.rar")
        try Data("Rar!\u{1A}\u{07}\u{00}".utf8).write(to: rar)

        await #expect(throws: DubPackImportError.unsupportedSource(fileExtension: "rar")) {
            try await DubPackInstaller.testing(library: temp.appending("library")).install(from: rar)
        }
    }

    @Test func refusesASourceThatIsNotThere() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }

        await #expect(throws: DubPackImportError.sourceMissing) {
            try await DubPackInstaller.testing(library: temp.appending("library")).install(from: temp.appending("gone.zip"))
        }
    }

    @Test func stopsWhenCancelled() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let library = temp.appending("library")
        let source = try makeSource(in: temp)
        let installer = DubPackInstaller.testing(library: library)

        let task = Task { try await installer.install(from: source.directory) }
        task.cancel()
        let result = await task.result

        guard case .failure(let error) = result else {
            Issue.record("a cancelled install should not finish")
            return
        }
        #expect(error as? DubPackImportError == .cancelled)
        #expect(contents(of: library).isEmpty)
    }
}
