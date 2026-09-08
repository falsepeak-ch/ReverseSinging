//
//  AudioFileManager.swift
//  ReverseSinging
//
//  File management for audio recordings
//

import Foundation

nonisolated final class AudioFileManager: @unchecked Sendable {
    static let shared = AudioFileManager()

    private nonisolated(unsafe) let fileManager = FileManager.default
    private let documentsDirectory: URL

    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        createDirectoriesIfNeeded()
    }

    // MARK: - Directory Management

    private func createDirectoriesIfNeeded() {
        let recordingsDir = recordingsDirectory()
        if !fileManager.fileExists(atPath: recordingsDir.path) {
            try? fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }
    }

    nonisolated func recordingsDirectory() -> URL {
        documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }

    // MARK: - Dub Directories

    /// Imported dub packs, one subdirectory per pack.
    nonisolated func dubPacksDirectory() -> URL {
        let url = documentsDirectory.appendingPathComponent("DubPacks", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    /// The user's recorded takes for one pack, named `<lineSlug>.caf`.
    nonisolated func dubTakesDirectory(packID: UUID) -> URL {
        let url = documentsDirectory
            .appendingPathComponent("DubTakes", isDirectory: true)
            .appendingPathComponent(packID.uuidString, isDirectory: true)
        createIfNeeded(url)
        return url
    }

    /// The user's booth footage for one pack, named `<lineSlug>.mov`.
    ///
    /// Separate from `dubTakesDirectory` on purpose: video is by far the largest thing this
    /// app writes, and "delete my footage" has to be answerable without touching the voice
    /// takes that footage was recorded against.
    nonisolated func dubBoothDirectory(packID: UUID) -> URL {
        let url = documentsDirectory
            .appendingPathComponent("DubBooth", isDirectory: true)
            .appendingPathComponent(packID.uuidString, isDirectory: true)
        createIfNeeded(url)
        return url
    }

    /// Every pack's booth footage, for the size shown in Settings and the button beside it.
    nonisolated func dubBoothRootDirectory() -> URL {
        let url = documentsDirectory.appendingPathComponent("DubBooth", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    /// How much booth footage is on disk, and how many packs it is spread across.
    nonisolated func boothFootageUsage() -> (bytes: Int64, packs: Int) {
        let root = dubBoothRootDirectory()
        guard let packDirs = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return (0, 0) }

        var bytes: Int64 = 0
        var packs = 0

        for dir in packDirs {
            guard let clips = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey]
            ), !clips.isEmpty else { continue }

            packs += 1
            for clip in clips {
                let size = (try? clip.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                bytes += Int64(size)
            }
        }

        return (bytes, packs)
    }

    /// Removes every booth clip, leaving the voice takes and the packs themselves alone.
    nonisolated func deleteAllBoothFootage() throws {
        let root = dubBoothRootDirectory()
        guard let packDirs = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return
        }
        for dir in packDirs {
            try fileManager.removeItem(at: dir)
        }
    }

    /// Rendered dub videos ready to share.
    nonisolated func dubExportsDirectory() -> URL {
        let url = documentsDirectory.appendingPathComponent("DubExports", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    /// Removes a pack's assets along with every take recorded against it.
    nonisolated func deleteDubPack(folderName: String, packID: UUID) throws {
        let packURL = dubPacksDirectory().appendingPathComponent(folderName, isDirectory: true)
        if fileManager.fileExists(atPath: packURL.path) {
            try fileManager.removeItem(at: packURL)
        }

        let takesURL = dubTakesDirectory(packID: packID)
        if fileManager.fileExists(atPath: takesURL.path) {
            try fileManager.removeItem(at: takesURL)
        }

        let boothURL = dubBoothDirectory(packID: packID)
        if fileManager.fileExists(atPath: boothURL.path) {
            try fileManager.removeItem(at: boothURL)
        }
    }

    private nonisolated func createIfNeeded(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - File Operations

    func createTemporaryAudioURL() -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "recording_\(timestamp).caf"
        return fileManager.temporaryDirectory.appendingPathComponent(filename)
    }

    func saveRecordingAsync(from temporaryURL: URL, withName name: String? = nil) async throws -> URL {
        try await Task.detached(priority: .userInitiated) { [self] in
            let filename = name ?? "recording_\(Date().timeIntervalSince1970).caf"
            let destinationURL = self.recordingsDirectory().appendingPathComponent(filename)

            if self.fileManager.fileExists(atPath: destinationURL.path) {
                try self.fileManager.removeItem(at: destinationURL)
            }

            try self.fileManager.copyItem(at: temporaryURL, to: destinationURL)

            return destinationURL
        }.value
    }

    func deleteRecording(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    func getAudioDuration(from url: URL) -> TimeInterval? {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = audioFile.processingFormat.sampleRate
        let frameCount = Double(audioFile.length)
        return frameCount / sampleRate
    }

    /// Async variant that runs on background thread
    func getAudioDurationAsync(from url: URL) async -> TimeInterval? {
        await Task.detached(priority: .userInitiated) {
            guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
            let sampleRate = audioFile.processingFormat.sampleRate
            let frameCount = Double(audioFile.length)
            return frameCount / sampleRate
        }.value
    }

    // MARK: - Cleanup

    func deleteAllTemporaryFiles() {
        let tempDirectory = fileManager.temporaryDirectory
        if let enumerator = fileManager.enumerator(at: tempDirectory, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.pathExtension == "caf" || url.pathExtension == "m4a" {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }
}

import AVFoundation
