//
//  WaveformSamplerTests.swift
//  DubAudioTests
//
//  A recording's shape, reduced to bars that can be laid over another's
//

import AVFoundation
import Foundation
import Testing
@testable import DubAudio

@Suite("Waveform Sampler")
struct WaveformSamplerTests {

    /// One second of tone: `first` amplitude for the first half, `second` for the rest.
    private func writeTone(first: Float, second: Float, to url: URL) throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100))
        buffer.frameLength = 44_100

        let samples = try #require(buffer.floatChannelData)[0]
        for frame in 0..<44_100 {
            let amplitude = frame < 22_050 ? first : second
            samples[frame] = amplitude * sinf(2 * .pi * 441 * Float(frame) / 44_100)
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }

    private func scratchFile() throws -> (url: URL, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("waveform-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory.appendingPathComponent("take.caf"), directory)
    }

    // MARK: - Sampling

    /// Peaks against the file's own loudest moment, so a quietly mastered reference and a take
    /// shouted into a phone compare in shape rather than in level.
    @Test func peaksAreDrawnAgainstTheRecordingsOwnLoudestMoment() async throws {
        let (url, directory) = try scratchFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeTone(first: 0.2, second: 0.05, to: url)

        let peaks = await WaveformSampler().samples(from: url, buckets: 10)

        #expect(peaks.count == 10)
        #expect(peaks.prefix(5).allSatisfy { abs($0 - 1) < 0.01 }, "\(peaks)")
        #expect(peaks.suffix(5).allSatisfy { abs($0 - 0.25) < 0.01 }, "\(peaks)")
    }

    @Test func anUnreadableFileDrawsAnEmptyRail() async throws {
        let (url, directory) = try scratchFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(await WaveformSampler().samples(from: url, buckets: 10).isEmpty)
        #expect(await WaveformSampler().samples(from: url, buckets: 0).isEmpty)
    }

    /// A take is re-recorded under the same name. Without invalidating, the previous take's
    /// shape is drawn over the new one.
    @Test func aReRecordedTakeIsOnlySampledAgainOnceInvalidated() async throws {
        let (url, directory) = try scratchFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sampler = WaveformSampler()
        try writeTone(first: 0.5, second: 0.1, to: url)
        let before = await sampler.samples(from: url, buckets: 4)

        try writeTone(first: 0.1, second: 0.5, to: url)
        #expect(await sampler.samples(from: url, buckets: 4) == before, "served from the cache")

        await sampler.invalidate(url)
        let after = await sampler.samples(from: url, buckets: 4)
        #expect(after != before)
        #expect(after.last.map { abs($0 - 1) < 0.01 } == true)
    }

    // MARK: - Scaling

    /// Both waveforms have to share seconds-per-bar, or a long take would be drawn at the
    /// reference's width and hide the very difference the overlay exists to show.
    @Test func aClipTwiceTheReferenceLengthGetsTwiceTheBars() {
        #expect(WaveformScaling.bucketCount(forDuration: 4, referenceDuration: 2, referenceBuckets: 96) == 192)
        #expect(WaveformScaling.bucketCount(forDuration: 1, referenceDuration: 2, referenceBuckets: 96) == 48)
    }

    @Test func aRunawayClipStopsAtTheOverrun() {
        #expect(
            WaveformScaling.bucketCount(forDuration: 600, referenceDuration: 2, referenceBuckets: 96)
                == 96 * WaveformScaling.maxOverrun
        )
    }

    @Test func nothingToScaleAgainstGivesNoBars() {
        #expect(WaveformScaling.bucketCount(forDuration: 3, referenceDuration: 0, referenceBuckets: 96) == 0)
        #expect(WaveformScaling.bucketCount(forDuration: 0, referenceDuration: 3, referenceBuckets: 96) == 0)
    }
}
