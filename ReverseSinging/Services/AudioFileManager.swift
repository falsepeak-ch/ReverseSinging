//
//  AudioFileManager.swift
//  ReverseSinging
//
//  File management for audio recordings
//

import Foundation

final class AudioFileManager: @unchecked Sendable {
    static let shared = AudioFileManager()

    private let fileManager = FileManager.default
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

    // MARK: - File Operations

    func createTemporaryAudioURL() -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "recording_\(timestamp).caf"
        return fileManager.temporaryDirectory.appendingPathComponent(filename)
    }

    func saveRecording(from temporaryURL: URL, withName name: String? = nil) throws -> URL {
        let filename = name ?? "recording_\(Date().timeIntervalSince1970).caf"
        let destinationURL = recordingsDirectory().appendingPathComponent(filename)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: temporaryURL, to: destinationURL)

        return destinationURL
    }

    /// Async variant that runs on background thread
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

    func deleteAllRecordings() throws {
        let recordingsDir = recordingsDirectory()
        if fileManager.fileExists(atPath: recordingsDir.path) {
            try fileManager.removeItem(at: recordingsDir)
            createDirectoriesIfNeeded()
        }
    }
}

import AVFoundation
