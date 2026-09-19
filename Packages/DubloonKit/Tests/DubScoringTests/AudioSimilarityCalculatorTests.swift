//
//  AudioSimilarityCalculatorTests.swift
//  DubScoringTests
//
//  The reverse-singing score: how alike an attempt and the original sound
//

import Foundation
import Testing
@testable import DubScoring

@Suite("Audio Similarity")
struct AudioSimilarityCalculatorTests {

    /// Bursts of tone in silence, in kept samples, standing in for a sung phrase.
    private func phrase(_ bursts: [Range<Int>], count: Int = 4_000, amplitude: Float = 0.8) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        for burst in bursts {
            for index in burst where index < count {
                samples[index] = amplitude * sin(Float(index) * 0.9)
            }
        }
        return samples
    }

    private let sung = [200..<600, 1_200..<1_500, 2_400..<3_000]

    // MARK: - Scoring

    @Test func aRecordingMatchesItselfPerfectly() {
        let original = phrase(sung)
        #expect(AudioSimilarityCalculator.similarity(original: original, comparison: original) > 99.9)
    }

    /// Scaled to the same peak before anything is compared: singing quietly is not singing badly.
    @Test func theSamePhraseSungQuietlyStillMatches() {
        let score = AudioSimilarityCalculator.similarity(
            original: phrase(sung),
            comparison: phrase(sung, amplitude: 0.1)
        )
        #expect(score > 99, "got \(score)")
    }

    @Test func aDifferentPhraseScoresLower() {
        let original = phrase(sung)
        let same = AudioSimilarityCalculator.similarity(original: original, comparison: original)
        let different = AudioSimilarityCalculator.similarity(
            original: original,
            comparison: phrase([0..<150, 700..<1_000, 3_300..<3_900])
        )

        #expect(different < same - 20, "\(different) against \(same)")
    }

    @Test func silenceMatchesNothing() {
        let silence = [Float](repeating: 0, count: 4_000)
        #expect(AudioSimilarityCalculator.similarity(original: phrase(sung), comparison: silence) == 0)
    }

    @Test func nothingToCompareScoresZero() {
        #expect(AudioSimilarityCalculator.similarity(original: [], comparison: phrase(sung)) == 0)
        #expect(AudioSimilarityCalculator.similarity(original: phrase(sung), comparison: []) == 0)
    }

    @Test func anUnreadableRecordingScoresZero() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).caf")
        #expect(await AudioSimilarityCalculator.similarity(original: missing, comparison: missing) == 0)
    }

    @Test func theScoreStaysOnTheScale() {
        var seed: UInt64 = 7
        let noise = (0..<3_000).map { _ -> Float in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(seed >> 40) / Float(1 << 24) - 0.5
        }

        let score = AudioSimilarityCalculator.similarity(original: noise, comparison: phrase(sung))
        #expect((0...100).contains(score))
    }

    // MARK: - Envelope

    /// The envelope is taken from a running total. It has to agree with the sum-per-sample it
    /// replaced, or every score in the game would quietly shift.
    @Test func theEnvelopeMatchesTheMovingAverageItReplaced() {
        let samples = phrase(sung, count: 1_000)
        let half = AudioSimilarityCalculator.envelopeWindow / 2

        let expected = samples.indices.map { index -> Float in
            let start = max(0, index - half)
            let end = min(samples.count, index + half)
            var sum: Float = 0
            for position in start..<end { sum += abs(samples[position]) }
            return sum / Float(end - start)
        }

        let actual = AudioSimilarityCalculator.envelope(of: samples)

        #expect(actual.count == expected.count)
        #expect(zip(actual, expected).allSatisfy { abs($0 - $1) < 0.0001 })
    }
}
