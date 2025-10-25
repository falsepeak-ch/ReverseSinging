//
//  AudioSimilarityCalculator.swift
//  ReverseSinging
//
//  Service to calculate similarity between two audio files
//

import AVFoundation
import Accelerate

final class AudioSimilarityCalculator: @unchecked Sendable {
    static let shared = AudioSimilarityCalculator()

    private init() {}

    // MARK: - Public API

    /// Calculate similarity between two audio files
    /// Returns a score from 0-100, where 100 is identical
    /// Runs on background thread to avoid blocking UI
    func calculateSimilarity(original: URL, comparison: URL) async -> Double {
        // Ensure we're running on a background thread
        await Task.detached(priority: .userInitiated) {
            print("📊 Calculating similarity between audio files...")

            do {
                // Extract audio data from both files
                let originalSamples = try await self.extractAudioSamples(from: original)
                let comparisonSamples = try await self.extractAudioSamples(from: comparison)

                guard !originalSamples.isEmpty, !comparisonSamples.isEmpty else {
                    print("❌ Empty audio samples")
                    return 0.0
                }

                // Normalize to same length
                let (normalizedOriginal, normalizedComparison) = self.normalizeLengths(
                    originalSamples,
                    comparisonSamples
                )

                // Calculate similarity score
                let score = self.calculateCorrelation(normalizedOriginal, normalizedComparison)

                print("✅ Similarity score: \(String(format: "%.1f", score))%")
                return score

            } catch {
                print("❌ Error calculating similarity: \(error)")
                return 0.0
            }
        }.value
    }

    // MARK: - Audio Processing

    private func extractAudioSamples(from url: URL) async throws -> [Float] {
        // Run file I/O on background thread
        try await Task.detached(priority: .userInitiated) {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = UInt32(audioFile.length)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw NSError(domain: "AudioSimilarity", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create audio buffer"
                ])
            }

            try audioFile.read(into: buffer)

            guard let floatData = buffer.floatChannelData?[0] else {
                throw NSError(domain: "AudioSimilarity", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to get float channel data"
                ])
            }

            // Convert to Swift array and downsample for efficiency
            let sampleCount = Int(buffer.frameLength)
            let downsampleFactor = 100 // Sample every 100th frame
            var samples: [Float] = []
            samples.reserveCapacity(sampleCount / downsampleFactor)

            for i in stride(from: 0, to: sampleCount, by: downsampleFactor) {
                samples.append(floatData[i])
            }

            return samples
        }.value
    }

    // MARK: - Normalization

    nonisolated private func normalizeLengths(_ array1: [Float], _ array2: [Float]) -> ([Float], [Float]) {
        let minLength = min(array1.count, array2.count)

        // Trim both to same length
        let trimmed1 = Array(array1.prefix(minLength))
        let trimmed2 = Array(array2.prefix(minLength))

        // Normalize amplitudes
        let normalized1 = normalizeAmplitude(trimmed1)
        let normalized2 = normalizeAmplitude(trimmed2)

        return (normalized1, normalized2)
    }

    nonisolated private func normalizeAmplitude(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }

        // Find max absolute value
        var maxVal: Float = 0.0
        vDSP_maxmgv(samples, 1, &maxVal, vDSP_Length(samples.count))

        guard maxVal > 0 else { return samples }

        // Normalize to [-1, 1] range
        var normalized = samples
        var divisor = maxVal
        vDSP_vsdiv(samples, 1, &divisor, &normalized, 1, vDSP_Length(samples.count))

        return normalized
    }

    // MARK: - Similarity Calculation

    nonisolated private func calculateCorrelation(_ array1: [Float], _ array2: [Float]) -> Double {
        guard array1.count == array2.count, !array1.isEmpty else { return 0.0 }

        let n = array1.count
        var correlation: Float = 0.0

        // Calculate dot product using Accelerate
        vDSP_dotpr(array1, 1, array2, 1, &correlation, vDSP_Length(n))

        // Normalize by length
        let normalizedCorrelation = correlation / Float(n)

        // Convert to percentage (map from [-1, 1] to [0, 100])
        // Values close to 1 mean similar, close to -1 mean inverted, 0 means uncorrelated
        let similarity = abs(normalizedCorrelation)

        // Apply forgiving non-linear scaling (square root)
        // pow(x, 0.5) is more generous than pow(x, 0.7)
        // Example: 0.6 → 0.77 (was 0.69), 0.7 → 0.84 (was 0.79), 0.8 → 0.89 (was 0.87)
        let scaledSimilarity = pow(similarity, 0.5)

        // Convert to 0-100 scale
        let score = Double(scaledSimilarity) * 100.0

        return max(0, min(100, score))
    }

    // MARK: - Synchronous Helper (for backwards compatibility)

    func calculateSimilaritySync(original: URL, comparison: URL) -> Double {
        var result: Double = 0.0
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            result = await calculateSimilarity(original: original, comparison: comparison)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }
}
