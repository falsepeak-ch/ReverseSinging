//
//  DubPlayerSourceTests.swift
//  ReverseSingingTests
//
//  The scene player playing the track it was asked for
//

import Testing
import AVFoundation
@testable import ReverseSinging

@Suite("Dub Player Sources")
@MainActor
struct DubPlayerSourceTests {

    /// Reference and take are deliberately different lengths, so which one is loaded can be
    /// read off the buffer without playing anything.
    private let referenceDuration: TimeInterval = 1.0
    private let takeDuration: TimeInterval = 2.0

    private func makePack() throws -> DubPack {
        let packID = UUID()
        let folder = "dubplayer-\(UUID().uuidString)"
        let directory = AudioFileManager.shared.dubPacksDirectory()
            .appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let slug = "001_Tester"
        try writeTone(to: directory.appendingPathComponent("\(slug).wav"), duration: referenceDuration)
        try writeTone(
            to: AudioFileManager.shared.dubTakesDirectory(packID: packID).appendingPathComponent("\(slug).caf"),
            duration: takeDuration
        )

        let line = DubLine(
            index: 1,
            slug: slug,
            character: "Tester",
            caption: "line",
            imageFile: "\(slug).jpg",
            referenceAudioFile: "\(slug).wav",
            startTime: 0,
            duration: referenceDuration
        )

        return DubPack(
            id: packID,
            title: "Source Pack",
            authors: [],
            iconFile: "\(slug).jpg",
            backingTrackFile: nil,
            folderName: folder,
            lines: [line],
            duration: 5
        )
    }

    private func writeTone(to url: URL, duration: TimeInterval) throws {
        let format = DubAudioLoader.canonicalFormat
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frames) {
            samples[frame] = 0.6 * sinf(2 * .pi * 440 * Float(frame) / Float(format.sampleRate))
        }
        try file.write(from: buffer)
    }

    private func seconds(_ frames: AVAudioFrameCount?) -> Double {
        Double(frames ?? 0) / DubAudioLoader.canonicalFormat.sampleRate
    }

    /// Watching the original and then playing your own dub has to actually swap the voices.
    /// The player caches loaded lines so a replay is instant, and the cache is keyed by line —
    /// so once a mode has been played, the other one reuses whatever the first one loaded.
    @Test func switchingModesLoadsTheOtherTrack() async throws {
        let pack = try makePack()
        defer {
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        let player = DubPlayer()

        await player.prepare(pack: pack, mode: .original)
        let asOriginal = seconds(player.loadedVoiceFrameLengthForTesting(slug: "001_Tester"))

        await player.prepare(pack: pack, mode: .myDub)
        let asMyDub = seconds(player.loadedVoiceFrameLengthForTesting(slug: "001_Tester"))

        #expect(abs(asOriginal - referenceDuration) < 0.05, "original loaded \(asOriginal)s")
        #expect(abs(asMyDub - takeDuration) < 0.05, "my dub loaded \(asMyDub)s")
    }

    /// And the same the other way round.
    @Test func switchingBackLoadsTheReferenceAgain() async throws {
        let pack = try makePack()
        defer {
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        let player = DubPlayer()

        await player.prepare(pack: pack, mode: .myDub)
        await player.prepare(pack: pack, mode: .original)
        let asOriginal = seconds(player.loadedVoiceFrameLengthForTesting(slug: "001_Tester"))

        #expect(abs(asOriginal - referenceDuration) < 0.05, "original loaded \(asOriginal)s")
    }
}
