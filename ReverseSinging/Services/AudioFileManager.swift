//
//  AudioFileManager.swift
//  ReverseSinging
//
//  File management for audio recordings
//

import Foundation

final class AudioFileManager {
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

    func recordingsDirectory() -> URL {
        documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }

    // MARK: - File Operations

    func createTemporaryAudioURL() -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "recording_\(timestamp).m4a"
        return fileManager.temporaryDirectory.appendingPathComponent(filename)
    }

    func saveRecording(from temporaryURL: URL, withName name: String? = nil) throws -> URL {
        let filename = name ?? "recording_\(Date().timeIntervalSince1970).m4a"
        let destinationURL = recordingsDirectory().appendingPathComponent(filename)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: temporaryURL, to: destinationURL)

        return destinationURL
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

    // MARK: - Cleanup

    func deleteAllTemporaryFiles() {
        let tempDirectory = fileManager.temporaryDirectory
        if let enumerator = fileManager.enumerator(at: tempDirectory, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.pathExtension == "m4a" {
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
