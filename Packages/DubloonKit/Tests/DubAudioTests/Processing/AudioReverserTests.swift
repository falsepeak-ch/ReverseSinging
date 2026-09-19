//
//  AudioReverserTests.swift
//  DubAudioTests
//
//  A recording played backwards, and back again
//

import AVFoundation
import Foundation
import Testing
import DubAudio

@Suite("Audio Reverser")
struct AudioReverserTests {

    /// Two channels of ramp, rising on the left and falling on the right, so every sample says
    /// where it came from.
    private func ramp(frames: Int) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)

        let channels = try #require(buffer.floatChannelData)
        for frame in 0..<frames {
            channels[0][frame] = Float(frame) / Float(frames)
            channels[1][frame] = -Float(frame) / Float(frames)
        }
        return buffer
    }

    private func scratch() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("reverser-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func write(_ buffer: AVAudioPCMBuffer, to url: URL) throws {
        let file = try AVAudioFile(
            forWriting: url,
            settings: buffer.format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try file.write(from: buffer)
    }

    @Test func everyChannelIsReversedInPlace() throws {
        let buffer = try ramp(frames: 1000)

        AudioReverser.reverse(buffer)

        let channels = try #require(buffer.floatChannelData)
        #expect(channels[0][0] == Float(999) / 1000)
        #expect(channels[0][999] == 0)
        #expect(channels[1][0] == -Float(999) / 1000)
        #expect(buffer.frameLength == 1000)
    }

    @Test func aFileComesOutBackwardsAtTheSameLength() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = directory.appendingPathComponent("original.caf")
        try write(try ramp(frames: 4410), to: original)

        let reversed = directory.appendingPathComponent("reversed.caf")
        try AudioReverser.reverseFile(at: original, to: reversed)

        let result = try DubAudioLoader.loadBuffer(from: reversed)
        let channels = try #require(result.floatChannelData)

        #expect(result.frameLength == 4410)
        #expect(result.format.channelCount == 2)
        #expect(abs(channels[0][0] - Float(4409) / 4410) < 0.0001)
        #expect(abs(channels[1][4409]) < 0.0001)
    }

    /// Nothing is lost on the way: the game compares against this file.
    @Test func reversingTwiceGivesTheRecordingBack() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = try ramp(frames: 4410)
        let original = directory.appendingPathComponent("original.caf")
        try write(source, to: original)

        let reversed = directory.appendingPathComponent("reversed.caf")
        let restored = directory.appendingPathComponent("restored.caf")
        try AudioReverser.reverseFile(at: original, to: reversed)
        try AudioReverser.reverseFile(at: reversed, to: restored)

        let result = try DubAudioLoader.loadBuffer(from: restored)
        let expected = try #require(source.floatChannelData)
        let actual = try #require(result.floatChannelData)

        #expect(result.frameLength == source.frameLength)
        for frame in stride(from: 0, to: 4410, by: 97) {
            #expect(actual[0][frame] == expected[0][frame])
            #expect(actual[1][frame] == expected[1][frame])
        }
    }

    @Test func anUnreadableRecordingThrowsAndWritesNothing() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let output = directory.appendingPathComponent("reversed.caf")

        #expect(throws: (any Error).self) {
            try AudioReverser.reverseFile(at: directory.appendingPathComponent("missing.caf"), to: output)
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }
}
