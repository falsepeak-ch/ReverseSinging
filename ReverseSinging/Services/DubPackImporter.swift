//
//  DubPackImporter.swift
//  ReverseSinging
//
//  Brings a dub pack folder or .zip into the app's own storage
//

import AVFoundation
import Foundation
import ZIPFoundation

/// Stages of an import, so a multi-minute video conversion can say what it is doing rather
/// than showing a bar that looks stuck.
nonisolated enum DubImportStage: Equatable {
    case copying
    case convertingVideo
    case reading

    var message: String {
        switch self {
        case .copying: return Strings.Dub.importing
        case .convertingVideo: return Strings.Dub.convertingVideo
        case .reading: return Strings.Dub.importReading
        }
    }
}

/// Copies a user-chosen pack into `Documents/DubPacks/`, parses it once, and caches the
/// parse as `manifest.json` so later launches don't re-read 60+ text files and re-measure
/// every reference wav.
nonisolated struct DubPackImporter {

    static let shared = DubPackImporter()

    private init() {}

    /// Imports a pack from a security-scoped URL (a folder or a `.zip`).
    /// Runs entirely off the main actor. A pack is tens of megabytes across ~190 files.
    typealias ProgressHandler = @Sendable (DubImportStage, Double) -> Void

    func importPack(from sourceURL: URL, progress: ProgressHandler? = nil) async throws -> DubPack {
        try await Task.detached(priority: .userInitiated) {
            let didScope = sourceURL.startAccessingSecurityScopedResource()
            defer { if didScope { sourceURL.stopAccessingSecurityScopedResource() } }

            progress?(.copying, 0.2)

            // Resolve to a plain directory containing _pack_info.ini
            let staging = try stagedDirectory(for: sourceURL)
            defer { staging.cleanup() }

            progress?(.copying, 0.6)

            let packRoot = try locatePackRoot(in: staging.url)
            let folderName = try install(packRoot, preferredName: sourceURL.deletingPathExtension().lastPathComponent)

            progress?(.copying, 1)

            let destination = AudioFileManager.shared.dubPacksDirectory()
                .appendingPathComponent(folderName, isDirectory: true)

            // The scene arrives as Ogg Theora, which nothing on iOS can play. Convert it
            // once here so every screen downstream deals in ordinary H.264.
            convertSceneVideoIfNeeded(in: destination) { value in
                progress?(.convertingVideo, value)
            }

            progress?(.reading, 0)

            do {
                let pack = try DubPackParser.parsePack(at: destination, folderName: folderName)
                try writeManifest(pack, to: destination)
                progress?(.reading, 1)
                return pack
            } catch {
                // Don't leave a half-imported pack behind for the library to trip over
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }.value
    }

    // MARK: - Video

    /// Converts `dub_video.ogv` to `dub_video.mp4` and deletes the original.
    ///
    /// Deliberately non-throwing: a pack whose video is corrupt, truncated or in some
    /// unexpected Theora flavour should still import and play from its stills. Losing the
    /// picture is a worse outcome than losing the whole scene.
    private func convertSceneVideoIfNeeded(
        in directory: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) {
        let fileManager = FileManager.default

        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        guard let source = contents.first(where: {
            $0.deletingPathExtension().lastPathComponent == DubPackParser.videoPrefix
                && Self.theoraExtensions.contains($0.pathExtension.lowercased())
        }) else { return }

        let destination = directory.appendingPathComponent("\(DubPackParser.videoPrefix).mp4")

        do {
            let written = try TheoraTranscoder.transcode(ogv: source, to: destination, progress: progress)

            // Check what landed on disk against what the decoder said it wrote, rather than
            // assuming. A scene video that comes out short is the one failure this whole path
            // cannot afford: it plays, it looks fine, and every line after the missing frames
            // is early. Which is exactly how a dropped-duplicate-frame bug went unnoticed
            // through a release. Better to fall back to the stills than to ship the drift.
            let measured = try Self.videoDuration(at: destination)
            let tolerance = max(0.05, written.duration * 0.001)

            guard abs(measured - written.duration) <= tolerance else {
                throw TheoraTranscoder.TranscodeError.lengthMismatch(
                    expected: written.duration,
                    actual: measured
                )
            }

            // The Theora original is by far the largest file in a pack and is useless once
            // converted, so it does not get to sit in the user's storage.
            try? fileManager.removeItem(at: source)
        } catch {
            print("⚠️ Dub scene video could not be converted, falling back to stills: \(error.localizedDescription)")
            try? fileManager.removeItem(at: destination)
            try? fileManager.removeItem(at: source)
        }
    }

    /// The duration of a written video, read back off disk.
    ///
    /// Synchronous on purpose. The whole convert runs on a detached task already, and the
    /// async `load(.duration)` would need this non-isolated helper to become async along with
    /// every caller above it.
    private static func videoDuration(at url: URL) throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else {
            throw TheoraTranscoder.TranscodeError.noFrames
        }
        return duration
    }

    // MARK: - Manifest

    func writeManifest(_ pack: DubPack, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pack)
        try data.write(to: directory.appendingPathComponent(DubPackParser.manifestFilename), options: .atomic)
    }

    func readManifest(at directory: URL) -> DubPack? {
        let url = directory.appendingPathComponent(DubPackParser.manifestFilename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DubPack.self, from: data)
    }

    // MARK: - Staging

    private struct Staging {
        let url: URL
        let isTemporary: Bool

        func cleanup() {
            guard isTemporary else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Unzips into a temp directory, or passes a folder through untouched.
    private func stagedDirectory(for sourceURL: URL) throws -> Staging {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)

        guard exists else { throw DubPackError.notAFolder }

        if isDirectory.boolValue {
            return Staging(url: sourceURL, isTemporary: false)
        }

        guard sourceURL.pathExtension.lowercased() == "zip" else {
            throw DubPackError.notAFolder
        }

        let unzipped = FileManager.default.temporaryDirectory
            .appendingPathComponent("dubpack-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: unzipped, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: sourceURL, to: unzipped)
        } catch {
            try? FileManager.default.removeItem(at: unzipped)
            throw DubPackError.unreadableArchive(error)
        }

        return Staging(url: unzipped, isTemporary: true)
    }

    /// Handles both zip layouts: files at the archive root, and a single wrapping folder
    /// (which is what most desktop "compress this folder" commands produce).
    private func locatePackRoot(in directory: URL) throws -> URL {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: directory.appendingPathComponent(DubPackParser.packInfoFilename).path) {
            return directory
        }

        let children = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for child in children {
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory, child.lastPathComponent != "__MACOSX" else { continue }

            if fileManager.fileExists(atPath: child.appendingPathComponent(DubPackParser.packInfoFilename).path) {
                return child
            }
        }

        throw DubPackError.missingPackInfo
    }

    // MARK: - Install

    /// Copies the pack into DubPacks/ and returns the folder name it landed under.
    /// Re-importing the same pack replaces the previous copy rather than accumulating.
    private func install(_ packRoot: URL, preferredName: String) throws -> String {
        let fileManager = FileManager.default
        let folderName = sanitize(preferredName.nilIfEmpty ?? packRoot.lastPathComponent)
        let destination = AudioFileManager.shared.dubPacksDirectory()
            .appendingPathComponent(folderName, isDirectory: true)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        // Copy the pack's own files only: no nested directories exist in this format, and
        // skipping them keeps a stray __MACOSX or thumbnail folder out of the install.
        let contents = try fileManager.contentsOfDirectory(
            at: packRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard !isDirectory, !Self.skippedExtensions.contains(item.pathExtension.lowercased()) else { continue }
            try fileManager.copyItem(at: item, to: destination.appendingPathComponent(item.lastPathComponent))
        }

        return folderName
    }

    /// Ogg containers a pack may ship its scene in. AVFoundation cannot decode Theora, so
    /// these are converted to H.264 during import and then deleted.
    static let theoraExtensions: Set<String> = ["ogv", "ogg"]

    /// Nothing is skipped at copy time any more: the Theora video has to land in the pack
    /// directory so it can be converted, and it is removed once it has been.
    private static let skippedExtensions: Set<String> = []

    private func sanitize(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = name
            .components(separatedBy: illegal)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.nilIfEmpty ?? "DubPack"
    }
}
