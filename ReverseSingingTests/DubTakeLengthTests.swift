//
//  DubTakeLengthTests.swift
//  ReverseSingingTests
//
//  A take is always the length of the line it replaces
//

import Testing
import AVFoundation
@testable import ReverseSinging

@Suite("Dub Take Length")
struct DubTakeLengthTests {

    private let sampleRate: Double = 44_100

    private func makeTone(duration: TimeInterval, amplitude: Float = 0.5) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("take-\(UUID().uuidString).caf")

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frames) {
            samples[frame] = amplitude * sinf(2 * .pi * 440 * Float(frame) / Float(sampleRate))
        }

        try file.write(from: buffer)
        return url
    }

    private func duration(of url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// The recorder is told to stop on the audio clock, but a take can still arrive long, an
    /// older recording, or a stop that landed late. And the mix drops each take into a slot
    /// of known size.
    @Test func trimsATakeThatRanOver() throws {
        let url = try makeTone(duration: 4.0)
        defer { try? FileManager.default.removeItem(at: url) }

        try DubAudioLoader.normalizeDuration(ofFileAt: url, to: 2.5)

        #expect(abs(try duration(of: url) - 2.5) < 0.001)
    }

    /// The case the recorder cannot handle for us: the performer pressed stop early.
    @Test func padsATakeThatWasCutShort() throws {
        let url = try makeTone(duration: 1.0)
        defer { try? FileManager.default.removeItem(at: url) }

        try DubAudioLoader.normalizeDuration(ofFileAt: url, to: 3.0)

        #expect(abs(try duration(of: url) - 3.0) < 0.001)
    }

    /// The padding has to be silence. Fresh buffer memory is not documented as zeroed, so
    /// without an explicit clear this is whatever was on the heap.
    @Test func thePaddingIsSilent() throws {
        let url = try makeTone(duration: 1.0)
        defer { try? FileManager.default.removeItem(at: url) }

        try DubAudioLoader.normalizeDuration(ofFileAt: url, to: 2.0)

        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        file.framePosition = AVAudioFramePosition(1.2 * format.sampleRate)

        let frames = AVAudioFrameCount(min(Int64(0.5 * format.sampleRate), file.length - file.framePosition))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        try file.read(into: buffer, frameCount: frames)

        var peak: Float = 0
        for frame in 0..<Int(buffer.frameLength) {
            peak = max(peak, abs(buffer.floatChannelData![0][frame]))
        }

        #expect(peak == 0)
    }

    /// The performance itself has to survive being padded. This is the user's take, not a
    /// spacer, and truncating or resampling it would be silent data loss.
    @Test func keepsWhatWasActuallyPerformed() throws {
        let url = try makeTone(duration: 1.0, amplitude: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }

        try DubAudioLoader.normalizeDuration(ofFileAt: url, to: 3.0)

        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(0.5 * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        try file.read(into: buffer, frameCount: frames)

        var peak: Float = 0
        for frame in 0..<Int(buffer.frameLength) {
            peak = max(peak, abs(buffer.floatChannelData![0][frame]))
        }

        #expect(peak > 0.4)
    }

    /// The usual case, and the one that must not rewrite the file for nothing.
    @Test func leavesATakeThatIsAlreadyRightAlone() throws {
        let url = try makeTone(duration: 2.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let before = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date

        try DubAudioLoader.normalizeDuration(ofFileAt: url, to: 2.0)

        let after = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        #expect(before == after)
        #expect(abs(try duration(of: url) - 2.0) < 0.001)
    }

    /// A line the parser could not measure must not have its take blanked.
    @Test func doesNothingWithoutADuration() throws {
        let url = try makeTone(duration: 1.5)
        defer { try? FileManager.default.removeItem(at: url) }

        try DubAudioLoader.normalizeDuration(ofFileAt: url, to: 0)

        #expect(abs(try duration(of: url) - 1.5) < 0.001)
    }
}
