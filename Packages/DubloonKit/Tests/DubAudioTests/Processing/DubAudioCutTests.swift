//
//  DubAudioCutTests.swift
//  DubAudioTests
//
//  A reel's audio is the chosen stretches, back to back, handed over at each join
//

import Testing
import Foundation
import AVFoundation
import DubAudio

@Suite("Audio Cut")
struct DubAudioCutTests {

    private let sampleRate: Double = 44_100

    /// A ten-second mix whose amplitude is the second it is in: 0.1 in the first, 0.2 in the
    /// next, and so on, so any stretch of it says where it came from.
    private func writeMix(to url: URL) throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2))
        let total = AVAudioFrameCount(10 * sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total))
        buffer.frameLength = total

        let channels = try #require(buffer.floatChannelData)
        for frame in 0..<Int(total) {
            let second = Float(frame / Int(sampleRate) + 1)
            let sample = 0.1 * second * sinf(2 * .pi * 300 * Float(frame) / Float(sampleRate))
            channels[0][frame] = sample
            channels[1][frame] = sample
        }

        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true
        ])
        try file.write(from: buffer)
    }

    private func read(_ url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        return buffer
    }

    /// Peak amplitude over a stretch of output time.
    private func peak(of buffer: AVAudioPCMBuffer, from start: Double, to end: Double) throws -> Float {
        let samples = try #require(buffer.floatChannelData)[0]
        let first = Int(start * sampleRate)
        let last = min(Int(buffer.frameLength), Int(end * sampleRate))
        var peak: Float = 0
        for frame in first..<last { peak = max(peak, abs(samples[frame])) }
        return peak
    }

    private func segment(_ start: Double, _ duration: Double) -> Range<TimeInterval> {
        start..<(start + duration)
    }

    private func scratch() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("audiocut-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - The cut

    @Test func theStretchesComeOutInOrderAndBackToBack() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mix = directory.appendingPathComponent("mix.wav")
        try writeMix(to: mix)

        // The third second, then the eighth.
        let cut = try DubAudioCut.cut(mix, to: [segment(2, 1), segment(7, 1)], in: directory)
        #expect(cut != mix)

        let output = try read(cut)
        #expect(abs(Double(output.frameLength) / sampleRate - 2) < 0.05, "two seconds long")

        #expect(abs(try peak(of: output, from: 0.2, to: 0.8) - 0.3) < 0.03, "the third second first")
        #expect(abs(try peak(of: output, from: 1.2, to: 1.8) - 0.8) < 0.05, "then the eighth")
    }

    /// The point of the file: the join is handed over, not butted.
    @Test func theJoinIsFadedThroughSilence() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mix = directory.appendingPathComponent("mix.wav")
        try writeMix(to: mix)

        // The same stretch twice, so the join is between two equally loud halves and the only
        // thing that can make it quiet is the fade.
        let output = try read(try DubAudioCut.cut(mix, to: [segment(4, 1), segment(4, 1)], in: directory))

        let fade = DubAudioCut.joinFade
        let atTheJoin = try peak(of: output, from: 1 - fade / 10, to: 1 + fade / 10)
        let beforeIt = try peak(of: output, from: 1 - fade * 3, to: 1 - fade * 2)
        let afterIt = try peak(of: output, from: 1 + fade * 2, to: 1 + fade * 3)

        #expect(atTheJoin < beforeIt / 4, "quiet on the way in: \(atTheJoin) against \(beforeIt)")
        #expect(atTheJoin < afterIt / 4, "and on the way out: \(atTheJoin) against \(afterIt)")
    }

    /// Only the joins. The cut starts and ends at full level, as the segments it is made of do.
    @Test func theEndsAreNotFaded() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mix = directory.appendingPathComponent("mix.wav")
        try writeMix(to: mix)

        let output = try read(try DubAudioCut.cut(mix, to: [segment(2, 1), segment(7, 1)], in: directory))

        #expect(try peak(of: output, from: 0, to: 0.02) > 0.2)
        #expect(try peak(of: output, from: 1.98, to: 2) > 0.6)
    }

    /// A cut of nothing has no audio to be, and says so rather than writing an empty file.
    @Test func aCutOfNothingIsRefused() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mix = directory.appendingPathComponent("mix.wav")
        try writeMix(to: mix)

        #expect(throws: DubAudioCut.CutError.nothingToCut) {
            try DubAudioCut.cut(mix, to: [], in: directory)
        }
    }

    // MARK: - Leaving the mix alone

    /// The scene from the top is what the mix already is. Re-encoding it would cost time to
    /// make it very slightly worse.
    @Test func theWholeSceneIsTheMixItself() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mix = directory.appendingPathComponent("mix.wav")
        try writeMix(to: mix)

        #expect(try DubAudioCut.cut(mix, to: [segment(0, 10)], in: directory) == mix)
        #expect(try DubAudioCut.cut(mix, to: [segment(0, 4)], in: directory) == mix,
                "and so is a cut from the top that stops early; the composer clamps it")
    }

    /// A single line from the middle of the scene is a cut with no joins, but it still has
    /// to be moved to the top of the file.
    @Test func aSingleLineIsCutToItself() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mix = directory.appendingPathComponent("mix.wav")
        try writeMix(to: mix)

        let output = try read(try DubAudioCut.cut(mix, to: [segment(4, 1)], in: directory))

        #expect(abs(Double(output.frameLength) / sampleRate - 1) < 0.05)
        #expect(abs(try peak(of: output, from: 0.1, to: 0.9) - 0.5) < 0.05)
    }

    @Test func aSegmentPastTheEndOfTheMixIsClampedRatherThanFatal() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mix = directory.appendingPathComponent("mix.wav")
        try writeMix(to: mix)

        let output = try read(try DubAudioCut.cut(mix, to: [segment(2, 1), segment(9.5, 3)], in: directory))

        #expect(abs(Double(output.frameLength) / sampleRate - 1.5) < 0.05)
    }
}
