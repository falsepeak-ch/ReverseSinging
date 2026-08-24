//
//  DubPackImporterTests.swift
//  ReverseSingingTests
//
//  Bringing packs in from a folder or a .zip
//

import Testing
import Foundation
import AVFoundation
import ZIPFoundation
@testable import ReverseSinging

/// Locates the test bundle so `test.ogv` can be found — there is no `Bundle.module` for a
/// target defined in an Xcode project.
private final class BundleToken {}

private enum TestFixtureError: Error {
    case missingTheoraFixture
}

@Suite("Dub Pack Import")
struct DubPackImporterTests {

    /// A minimal but complete pack on disk, outside the app's own storage.
    private func makeSourcePack(named name: String, includeVideo: Bool = false,
        includeBrokenVideo: Bool = false) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dubsource-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try """
        [data]

        title="Imported Scene"
        icon="001_Hero.jpg"
        authors=["Tester"]
        """.write(to: directory.appendingPathComponent(DubPackParser.packInfoFilename), atomically: true, encoding: .utf8)

        for (offset, timestamp) in [0.0, 3.5].enumerated() {
            let slug = String(format: "%03d_Hero", offset + 1)

            try """
            [data]

            caption="line \(offset + 1)"
            image="\(slug).jpg"
            dub_timestamps=[\(timestamp)]
            dub_characters=["Hero"]
            """.write(to: directory.appendingPathComponent("\(slug).txt"), atomically: true, encoding: .utf8)

            try Data([0xFF, 0xD8, 0xFF]).write(to: directory.appendingPathComponent("\(slug).jpg"))
            try writeSilence(to: directory.appendingPathComponent("\(slug).wav"), duration: 1.0)
        }

        if includeVideo {
            guard let fixture = Bundle(for: BundleToken.self).url(
                forResource: "test", withExtension: "ogv"
            ) else {
                throw TestFixtureError.missingTheoraFixture
            }
            try FileManager.default.copyItem(
                at: fixture,
                to: directory.appendingPathComponent("dub_video.ogv")
            )
        }

        if includeBrokenVideo {
            // Ogg-shaped noise: the importer must survive it, not abort the pack.
            try Data(count: 4096).write(to: directory.appendingPathComponent("dub_video.ogv"))
        }

        return directory
    }

    private func writeSilence(to url: URL, duration: TimeInterval) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(duration * format.sampleRate))!
        buffer.frameLength = buffer.frameCapacity
        try file.write(from: buffer)
    }

    private func cleanUp(_ pack: DubPack, source: URL) {
        try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        try? FileManager.default.removeItem(at: source.deletingLastPathComponent())
    }

    // MARK: - Folder

    @Test func importsAFolder() async throws {
        let source = try makeSourcePack(named: "Scene From Files")
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        #expect(pack.title == "Imported Scene")
        #expect(pack.lines.count == 2)
        #expect(FileManager.default.fileExists(atPath: pack.directoryURL.path))
        #expect(FileManager.default.fileExists(atPath: pack.referenceAudioURL(for: pack.lines[0]).path))
    }

    @Test func writesAManifestForFastReloads() async throws {
        let source = try makeSourcePack(named: "Manifest Scene")
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        let manifestURL = pack.directoryURL.appendingPathComponent(DubPackParser.manifestFilename)
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))

        let cached = DubPackImporter.shared.readManifest(at: pack.directoryURL)
        #expect(cached?.id == pack.id)
        #expect(cached?.lines.count == pack.lines.count)
    }

    /// A Theora video is converted to H.264 during import, and the original — by far the
    /// biggest file in a pack — is thrown away once it has been.
    @Test func convertsTheSceneVideoAndDropsTheOriginal() async throws {
        let source = try makeSourcePack(named: "Video Scene", includeVideo: true)
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        let original = pack.directoryURL.appendingPathComponent("dub_video.ogv")
        let converted = pack.directoryURL.appendingPathComponent("dub_video.mp4")

        #expect(!FileManager.default.fileExists(atPath: original.path))
        #expect(FileManager.default.fileExists(atPath: converted.path))
        #expect(pack.videoFile == "dub_video.mp4")

        // Existence alone would also pass for a one-frame black clip, so check the
        // conversion actually carried the source's shape across.
        let asset = AVURLAsset(url: converted)
        let duration = try await asset.load(.duration).seconds
        let track = try await asset.loadTracks(withMediaType: .video).first

        #expect(abs(duration - 9.0) < 0.2)
        #expect(track != nil)

        if let track {
            let size = try await track.load(.naturalSize)
            #expect(Int(size.width) == 640)
            #expect(Int(size.height) == 480)
        }
    }

    /// A video that cannot be decoded must not fail the import: the pack still has its
    /// stills, and losing the picture beats losing the whole scene.
    @Test func stillImportsWhenTheVideoCannotBeConverted() async throws {
        let source = try makeSourcePack(named: "Broken Video Scene", includeBrokenVideo: true)
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        #expect(pack.lines.count == 2)
        #expect(pack.videoFile == nil)
        // Neither the unusable original nor a half-written conversion is left behind.
        #expect(!FileManager.default.fileExists(
            atPath: pack.directoryURL.appendingPathComponent("dub_video.ogv").path))
        #expect(!FileManager.default.fileExists(
            atPath: pack.directoryURL.appendingPathComponent("dub_video.mp4").path))
    }

    /// Manifests written before video support decode with `videoFile == nil`. The library
    /// must notice the video sitting in the folder rather than trusting that stale answer
    /// forever — otherwise the scene silently keeps showing stills.
    ///
    /// Checks the staleness rule directly rather than through `reload()`: that scans the
    /// shared packs directory, which sibling tests are concurrently writing to.
    @MainActor
    @Test func detectsAVideoAManifestPredates() async throws {
        let source = try makeSourcePack(named: "Legacy Manifest Scene", includeVideo: true)
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        #expect(pack.videoFile == "dub_video.mp4")

        let library = DubPackLibrary()

        // A manifest the way an older build would have written it: same pack, no video.
        let legacy = DubPack(
            id: pack.id, title: pack.title, authors: pack.authors, iconFile: pack.iconFile,
            backingTrackFile: pack.backingTrackFile, videoFile: nil,
            folderName: pack.folderName, lines: pack.lines, duration: pack.duration
        )

        #expect(library.manifestIsMissingAVideoOnDisk(legacy, in: pack.directoryURL),
                "a stale manifest hiding an on-disk video must force a re-parse")
        #expect(!library.manifestIsMissingAVideoOnDisk(pack, in: pack.directoryURL),
                "an up-to-date manifest must keep using the fast path")
    }

    @Test func reimportingReplacesRatherThanDuplicates() async throws {
        let source = try makeSourcePack(named: "Repeat Scene")

        let first = try await DubPackImporter.shared.importPack(from: source)
        let second = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(second, source: source) }

        #expect(first.folderName == second.folderName)

        let installed = try FileManager.default.contentsOfDirectory(
            at: AudioFileManager.shared.dubPacksDirectory(),
            includingPropertiesForKeys: nil
        )
        #expect(installed.filter { $0.lastPathComponent == second.folderName }.count == 1)
    }

    @Test func rejectsAFolderWithoutPackInfo() async throws {
        let source = try makeSourcePack(named: "Broken Scene")
        try FileManager.default.removeItem(at: source.appendingPathComponent(DubPackParser.packInfoFilename))
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        await #expect(throws: DubPackError.self) {
            _ = try await DubPackImporter.shared.importPack(from: source)
        }
    }

    // MARK: - Zip

    @Test func importsAZipWithAWrappingFolder() async throws {
        let source = try makeSourcePack(named: "Zipped Scene")
        let archive = source.deletingLastPathComponent().appendingPathComponent("pack.zip")

        // Zipping the folder itself produces the common "one folder inside" layout
        try FileManager.default.zipItem(at: source, to: archive, shouldKeepParent: true)

        let pack = try await DubPackImporter.shared.importPack(from: archive)
        defer { cleanUp(pack, source: source) }

        #expect(pack.title == "Imported Scene")
        #expect(pack.lines.count == 2)
    }

    @Test func importsAZipWithFilesAtTheRoot() async throws {
        let source = try makeSourcePack(named: "Flat Scene")
        let archive = source.deletingLastPathComponent().appendingPathComponent("flat.zip")

        try FileManager.default.zipItem(at: source, to: archive, shouldKeepParent: false)

        let pack = try await DubPackImporter.shared.importPack(from: archive)
        defer { cleanUp(pack, source: source) }

        #expect(pack.lines.count == 2)
    }
}
