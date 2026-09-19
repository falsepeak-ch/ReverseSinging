//
//  DubAudioLoaderTests.swift
//  DubAudioTests
//
//  Every frame of a file, in the one format the voices play in
//

import AVFoundation
import Foundation
import Testing
import DubAudio

@Suite("Dub Audio Loader")
struct DubAudioLoaderTests {

    /// `seconds` of 441 Hz tone at `sampleRate`, `channels` wide, written to a new file.
    private func writeTone(seconds: Double, sampleRate: Double = 44_100, channels: AVAudioChannelCount = 1) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("loader-\(UUID().uuidString).caf")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames

        let data = try #require(buffer.floatChannelData)
        for channel in 0..<Int(channels) {
            for frame in 0..<Int(frames) {
                data[channel][frame] = 0.5 * sinf(2 * .pi * 441 * Float(frame) / Float(sampleRate))
            }
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
        return url
    }

    /// A single read of a one-second file used to come back 68 frames short, and everything that
    /// loads audio through here, the waveform, the mix and both scorers, lost the end of the clip.
    @Test(arguments: [0.1, 1.0, 3.7])
    func everyFrameOfTheFileIsRead(seconds: Double) throws {
        let url = try writeTone(seconds: seconds)
        defer { try? FileManager.default.removeItem(at: url) }

        let buffer = try DubAudioLoader.loadBuffer(from: url)

        #expect(Int64(buffer.frameLength) == (try AVAudioFile(forReading: url)).length)
        #expect(buffer.frameLength == AVAudioFrameCount(seconds * 44_100))
    }

    @Test func anEmptyOrMissingFileThrows() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).caf")
        #expect(throws: (any Error).self) { try DubAudioLoader.loadBuffer(from: missing) }
    }

    /// A 48 kHz stereo reference and a 44.1 kHz mono take have to play through one voice node.
    @Test func aVoiceIsConvertedToTheCanonicalFormat() throws {
        let url = try writeTone(seconds: 1, sampleRate: 48_000, channels: 2)
        defer { try? FileManager.default.removeItem(at: url) }

        let voice = try DubAudioLoader.loadVoiceBuffer(from: url)

        #expect(voice.format == DubAudioLoader.canonicalFormat)
        #expect(abs(Double(voice.frameLength) / DubAudioLoader.canonicalFormat.sampleRate - 1) < 0.01)
    }

    /// A line dropped onto the timeline must not click at either end.
    @Test func aVoiceIsFadedAtBothEdges() throws {
        let url = try writeTone(seconds: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }

        let voice = try DubAudioLoader.loadVoiceBuffer(from: url)
        let samples = try #require(voice.floatChannelData)[0]
        let last = Int(voice.frameLength) - 1

        #expect(samples[0] == 0)
        #expect(abs(samples[last]) < 0.01)

        let unfaded = try DubAudioLoader.loadVoiceBuffer(from: url, applyFades: false)
        #expect(abs(try #require(unfaded.floatChannelData)[0][last]) > abs(samples[last]))
    }

    @Test func playbackFromPartwayThroughALineStartsThere() throws {
        let url = try writeTone(seconds: 1)
        defer { try? FileManager.default.removeItem(at: url) }

        let buffer = try DubAudioLoader.loadBuffer(from: url)

        #expect(DubAudioLoader.trimming(buffer, fromOffset: 0) === buffer)
        #expect(DubAudioLoader.trimming(buffer, fromOffset: 0.25)?.frameLength == 33_075)
        #expect(DubAudioLoader.trimming(buffer, fromOffset: 2) == nil, "an offset past the end has nothing to play")
    }
}
