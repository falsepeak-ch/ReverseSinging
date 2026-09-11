//
//  DubPlayerSeekTests.swift
//  ReverseSingingTests
//
//  Moving the head of a held scene
//

import Testing
import AVFoundation
@testable import ReverseSinging
import DubAudio

@Suite("Dub Player Seek")
@MainActor
struct DubPlayerSeekTests {

    private func makePack(duration: TimeInterval) throws -> DubPack {
        let packID = UUID()
        let folder = "dubseek-\(UUID().uuidString)"
        let directory = AudioFileManager.shared.dubPacksDirectory()
            .appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let slug = "001_Tester"
        try writeTone(to: directory.appendingPathComponent("\(slug).wav"), duration: 1)

        let line = DubLine(
            index: 1,
            slug: slug,
            character: "Tester",
            caption: "line",
            imageFile: "\(slug).jpg",
            referenceAudioFile: "\(slug).wav",
            startTime: 0,
            duration: 1
        )

        return DubPack(
            id: packID,
            title: "Seek Pack",
            authors: [],
            iconFile: "\(slug).jpg",
            backingTrackFile: nil,
            folderName: folder,
            lines: [line],
            duration: duration
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
            samples[frame] = 0.5 * sinf(2 * .pi * 440 * Float(frame) / Float(format.sampleRate))
        }
        try file.write(from: buffer)
    }

    /// A held scene moves its head without starting anything.
    @Test func seekingAHeldSceneMovesTheHead() async throws {
        let player = DubPlayer()
        await player.prepare(pack: try makePack(duration: 10), mode: .original)

        player.seek(to: 4)

        #expect(player.currentTime == 4)
        #expect(player.isPlaying == false)
    }

    /// The head cannot leave the scene at either end.
    @Test func theHeadIsClampedToTheScene() async throws {
        let player = DubPlayer()
        await player.prepare(pack: try makePack(duration: 10), mode: .original)

        player.seek(to: 30)
        #expect(player.currentTime == 10)

        player.seek(to: -3)
        #expect(player.currentTime == 0)
    }

    /// Nothing loaded, nothing to move. A seek before `prepare` is a no-op rather than a head
    /// pointing into a scene that does not exist yet.
    @Test func seekingBeforeAnythingIsLoadedDoesNothing() {
        let player = DubPlayer()

        player.seek(to: 5)

        #expect(player.currentTime == 0)
    }
}
