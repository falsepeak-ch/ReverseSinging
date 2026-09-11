//
//  AudioSimilarityCalculator.swift
//  DubScoring
//
//  How alike two recordings of the same sounds are, for the reverse-singing game
//

public import Foundation
import AVFoundation
import Accelerate
import DubAudio

/// Scores how closely an attempt matches an original recording, 0...100.
///
/// The reverse-singing game plays a recording backwards and asks the player to sing what they
/// heard, so both recordings are of the *same* sounds and comparing their shapes is a fair
/// question. A dub is a different game, with its own scorer: see `DubScorer`.
///
/// Two measures, both of amplitude rather than pitch, after the quiet parts of each recording
/// are silenced and both are cut to the shorter and scaled to the same peak:
/// - **Shape**, three quarters of the score: a smoothed envelope of each, correlated.
/// - **Energy**, the rest: loudness over coarser windows, correlated.
///
/// The combined correlation is bent by x^0.7, generous in the middle and exact at the top:
/// 0.9 scores 93, 0.7 scores 79, 0.5 scores 63.
public enum AudioSimilarityCalculator {

    /// Every nth sample is kept when a file is read: enough for an envelope, at a twentieth of
    /// the arithmetic.
    static let downsampleFactor = 20

    /// Samples at or below this fraction of a recording's own peak are counted as silence.
    static let silenceFraction: Float = 0.10

    /// The shape envelope's moving-average window, in kept samples.
    static let envelopeWindow = 75

    /// The energy measure's window, in kept samples.
    static let energyWindow = 125

    /// How much of the score the shape carries; energy carries the rest.
    static let shapeWeight: Float = 0.75

    static let curve: Float = 0.7

    // MARK: - Scoring

    /// Scores the recording at `comparison` against the one at `original`.
    ///
    /// Zero when either cannot be read or holds nothing: an attempt that cannot be measured has
    /// not matched anything.
    @concurrent
    public static func similarity(original: URL, comparison: URL) async -> Double {
        guard let originalSamples = try? samples(from: original),
              let comparisonSamples = try? samples(from: comparison) else { return 0 }

        return similarity(original: originalSamples, comparison: comparisonSamples)
    }

    /// The measurement on samples already read, 0...100.
    public static func similarity(original: [Float], comparison: [Float]) -> Double {
        guard !original.isEmpty, !comparison.isEmpty else { return 0 }

        // Silenced against each recording's own peak first, so a loud passage in one is not
        // what decides what counts as quiet in the other.
        let length = min(original.count, comparison.count)
        let first = scaledToPeak(Array(silencingQuietParts(of: original).prefix(length)))
        let second = scaledToPeak(Array(silencingQuietParts(of: comparison).prefix(length)))

        // Direction is ignored: similarity, not polarity.
        let shape = abs(Correlation.pearson(envelope(of: first), envelope(of: second)))
        let energy = abs(Correlation.pearson(energy(of: first), energy(of: second)))
        let combined = shape * shapeWeight + energy * (1 - shapeWeight)

        let scaled = pow(min(1, max(0, combined)), curve)
        return min(100, max(0, Double(scaled) * 100))
    }

    // MARK: - Reading

    /// The first channel of a file, keeping every `downsampleFactor`th sample.
    static func samples(from url: URL) throws -> [Float] {
        let buffer = try DubAudioLoader.loadBuffer(from: url)
        guard let channel = buffer.floatChannelData?[0] else { return [] }

        return stride(from: 0, to: Int(buffer.frameLength), by: downsampleFactor).map { channel[$0] }
    }

    // MARK: - Measures

    private static func silencingQuietParts(of samples: [Float]) -> [Float] {
        let threshold = vDSP.maximumMagnitude(samples) * silenceFraction
        return samples.map { abs($0) > threshold ? $0 : 0 }
    }

    private static func scaledToPeak(_ samples: [Float]) -> [Float] {
        let peak = vDSP.maximumMagnitude(samples)
        guard peak > 0 else { return samples }
        return vDSP.divide(samples, peak)
    }

    /// Each sample's magnitude averaged over `envelopeWindow` around it.
    ///
    /// From a running total rather than a sum per sample, which was a nested loop seventy-five
    /// deep over every sample of the take.
    static func envelope(of samples: [Float]) -> [Float] {
        let half = envelopeWindow / 2
        var running = [Double](repeating: 0, count: samples.count + 1)
        for (index, sample) in samples.enumerated() {
            running[index + 1] = running[index] + Double(abs(sample))
        }

        return samples.indices.map { index in
            let start = max(0, index - half)
            let end = min(samples.count, index + half)
            return Float((running[end] - running[start]) / Double(end - start))
        }
    }

    /// RMS over consecutive `energyWindow`s.
    static func energy(of samples: [Float]) -> [Float] {
        stride(from: 0, to: samples.count, by: energyWindow).map { start in
            let window = samples[start..<min(start + energyWindow, samples.count)]
            let sumOfSquares = window.reduce(Float(0)) { $0 + $1 * $1 }
            return (sumOfSquares / Float(window.count)).squareRoot()
        }
    }
}
