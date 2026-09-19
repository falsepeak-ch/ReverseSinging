//
//  DubPackImporterTests.swift
//  ReverseSingingTests
//
//  What the app adds to an import: identity, speech windows and the manifest
//

import AVFoundation
import DubPackKit
import Foundation
import Testing
@testable import ReverseSinging

/// Locates the test bundle so `test.ogv` can be found. There is no `Bundle.module` for a
/// target defined in an Xcode project.
private final class BundleToken {}

/// Installing, reading and every pack variation are DubPackKit's, and tested in its package.
/// These cover the app's side of an import, through the real shared importer.
@Suite("Dub Pack Import")
struct DubPackImporterTests {

    /// A minimal complete pack on disk, outside the app's own storage.
    private func makeSourcePack(named name: String, includeVideo: Bool = false) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dubsource-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try """
        [data]

        title="Imported Scene"
        icon="001_Hero.jpg"
        authors=["Tester"]
        """.write(to: directory.appendingPathComponent("_pack_info.ini"), atomically: true, encoding: .utf8)

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
            let fixture = try #require(Bundle(for: BundleToken.self).url(forResource: "test", withExtension: "ogv"))
            try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent("dub_video.ogv"))
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

    // MARK: - Importing

    @Test func importsAPackIntoTheLibraryWithItsSpeechMeasured() async throws {
        let source = try makeSourcePack(named: "Scene-\(UUID().uuidString.prefix(6))")
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        #expect(pack.title == "Imported Scene")
        #expect(pack.folderName == source.lastPathComponent)
        #expect(pack.lines.count == 2)
        #expect(pack.hasMeasuredSpeech, "speech windows are measured at import, not later")
        #expect(FileManager.default.fileExists(atPath: pack.referenceAudioURL(for: pack.lines[0]).path))
    }

    @Test func writesAManifestForFastReloads() async throws {
        let source = try makeSourcePack(named: "Manifest-\(UUID().uuidString.prefix(6))")
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        let cached = try #require(DubPackManifest.read(at: pack.directoryURL))
        #expect(cached.id == pack.id)
        #expect(cached.lines.map(\.slug) == pack.lines.map(\.slug))
    }

    /// A failure arrives as DubPackKit's error, for `DubPackImportMessage` to put into words.
    @Test func aFolderWithNoPackInItFailsWithTheKitsError() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("dubsource-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: source) }

        await #expect(throws: DubPackImportError.noPackFound) {
            try await DubPackImporter.shared.importPack(from: source)
        }
    }

    // MARK: - Identity

    /// Bringing the same pack in again replaces the copy on disk but not the pack: the takes
    /// live under its id, and a rebuilt starter pack that changed id would orphan every line
    /// the user had recorded against it.
    @Test func reimportingAPackKeepsItsIdentity() async throws {
        let name = "Reimported-\(UUID().uuidString.prefix(6))"
        let first = try makeSourcePack(named: name)
        let second = try makeSourcePack(named: name)

        let original = try await DubPackImporter.shared.importPack(from: first)
        let replacement = try await DubPackImporter.shared.importPack(from: second)
        defer {
            cleanUp(replacement, source: second)
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
        }

        #expect(replacement.id == original.id)
        #expect(replacement.folderName == original.folderName)
    }

    /// A manifest that is out of date is replaced by reading the folder again, and the pack it
    /// describes must come back as the same pack: same id, so the takes stay attached.
    @Test func reReadingAStaleManifestKeepsTheIdentity() async throws {
        let source = try makeSourcePack(named: "Stale-\(UUID().uuidString.prefix(6))")
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        // The manifest an older build would have written: no speech windows.
        let legacy = DubPack(
            id: pack.id, title: pack.title, authors: pack.authors, iconFile: pack.iconFile,
            backingTrackFile: pack.backingTrackFile, videoFile: pack.videoFile,
            folderName: pack.folderName,
            lines: pack.lines.map {
                DubLine(
                    id: $0.id, index: $0.index, slug: $0.slug, character: $0.character, caption: $0.caption,
                    imageFile: $0.imageFile, referenceAudioFile: $0.referenceAudioFile,
                    startTime: $0.startTime, duration: $0.duration
                )
            },
            duration: pack.duration,
            importedAt: pack.importedAt
        )
        try DubPackManifest.write(legacy, to: pack.directoryURL)

        let reloaded = try #require(await DubPackLibrary.load(from: pack.directoryURL))

        #expect(reloaded.id == pack.id)
        #expect(abs(reloaded.importedAt.timeIntervalSince(pack.importedAt)) < 1)
        #expect(reloaded.hasMeasuredSpeech)
        #expect(DubPackManifest.read(at: pack.directoryURL)?.hasMeasuredSpeech == true)
    }

    // MARK: - Staleness

    /// Manifests written before video support decode with `videoFile == nil`. The library
    /// must notice the video sitting in the folder rather than trusting that stale answer
    /// forever, otherwise the scene silently keeps showing stills.
    ///
    /// Checks the staleness rule directly rather than through `reload()`: that scans the
    /// shared packs directory, which sibling tests are concurrently writing to.
    @Test func detectsAVideoAManifestPredates() async throws {
        let source = try makeSourcePack(named: "Legacy-\(UUID().uuidString.prefix(6))", includeVideo: true)
        let pack = try await DubPackImporter.shared.importPack(from: source)
        defer { cleanUp(pack, source: source) }

        #expect(pack.videoFile == "dub_video.mp4")

        let legacy = DubPack(
            id: pack.id, title: pack.title, authors: pack.authors, iconFile: pack.iconFile,
            backingTrackFile: pack.backingTrackFile, videoFile: nil,
            folderName: pack.folderName, lines: pack.lines, duration: pack.duration
        )

        #expect(await DubPackLibrary.manifestIsMissingAVideoOnDisk(legacy, in: pack.directoryURL),
                "a stale manifest hiding an on-disk video must force a re-read")
        #expect(await !DubPackLibrary.manifestIsMissingAVideoOnDisk(pack, in: pack.directoryURL),
                "an up-to-date manifest must keep using the fast path")
    }
}
