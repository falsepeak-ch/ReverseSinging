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

                print("📊 [DEBUG] Original samples: \(originalSamples.count), Comparison samples: \(comparisonSamples.count)")

                guard !originalSamples.isEmpty, !comparisonSamples.isEmpty else {
                    print("❌ Empty audio samples")
                    return 0.0
                }

                // Normalize to same length
                let (normalizedOriginal, normalizedComparison) = self.normalizeLengths(
                    originalSamples,
                    comparisonSamples
                )

                print("📊 [DEBUG] After normalization: \(normalizedOriginal.count) samples")

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
            let downsampleFactor = 20 // Sample every 20th frame (5x more data than before)
            var samples: [Float] = []
            samples.reserveCapacity(sampleCount / downsampleFactor)

            for i in stride(from: 0, to: sampleCount, by: downsampleFactor) {
                samples.append(floatData[i])
            }

            return samples
        }.value
    }

    // MARK: - Audio Filtering

    /// Filter out silence and low-amplitude sounds
    /// Only keep samples above 10% of max amplitude (gentle for reversed audio)
    nonisolated private func filterSignificantSounds(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }

        // Find max amplitude
        var maxVal: Float = 0.0
        vDSP_maxmgv(samples, 1, &maxVal, vDSP_Length(samples.count))

        let threshold = maxVal * 0.10 // 10% threshold (gentle, keeps more audio data)

        // Filter samples above threshold
        return samples.map { abs($0) > threshold ? $0 : 0.0 }
    }

    /// Extract smooth envelope of audio for shape comparison
    nonisolated private func extractEnvelope(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }

        var envelope = [Float](repeating: 0, count: samples.count)

        // Moderate moving average for smoothing (window = 75 samples, balanced sensitivity)
        let windowSize = 75

        for i in 0..<samples.count {
            let start = max(0, i - windowSize/2)
            let end = min(samples.count, i + windowSize/2)
            var sum: Float = 0.0

            for j in start..<end {
                sum += abs(samples[j])
            }

            envelope[i] = sum / Float(end - start)
        }

        return envelope
    }

    /// Calculate RMS (energy) windows for loudness pattern comparison
    nonisolated private func calculateRMSWindows(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }

        var rmsValues = [Float]()
        let windowSize = 125 // Moderate energy window (balanced accuracy)

        for i in stride(from: 0, to: samples.count, by: windowSize) {
            let end = min(i + windowSize, samples.count)
            let window = Array(samples[i..<end])

            // Calculate RMS (root mean square)
            var sumOfSquares: Float = 0.0
            for sample in window {
                sumOfSquares += sample * sample
            }
            let rms = sqrt(sumOfSquares / Float(window.count))
            rmsValues.append(rms)
        }

        return rmsValues
    }

    // MARK: - Normalization

    nonisolated private func normalizeLengths(_ array1: [Float], _ array2: [Float]) -> ([Float], [Float]) {
        print("📊 [DEBUG] Before filtering: array1=\(array1.count), array2=\(array2.count)")

        // Filter out silence/low sounds FIRST (gentle 10% threshold)
        let filtered1 = filterSignificantSounds(array1)
        let filtered2 = filterSignificantSounds(array2)

        print("📊 [DEBUG] After filtering: filtered1=\(filtered1.count), filtered2=\(filtered2.count)")

        let minLength = min(filtered1.count, filtered2.count)

        // Trim both to same length
        let trimmed1 = Array(filtered1.prefix(minLength))
        let trimmed2 = Array(filtered2.prefix(minLength))

        // Normalize amplitudes
        let normalized1 = normalizeAmplitude(trimmed1)
        let normalized2 = normalizeAmplitude(trimmed2)

        print("📊 [DEBUG] Final normalized length: \(normalized1.count)")

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
        guard array1.count == array2.count, !array1.isEmpty else {
            print("📊 [DEBUG] Array length mismatch or empty")
            return 0.0
        }

        // Method 1: Envelope comparison (shape) - USE PROPER PEARSON CORRELATION
        let envelope1 = extractEnvelope(array1)
        let envelope2 = extractEnvelope(array2)

        let envelopeScore = pearsonCorrelation(envelope1, envelope2)

        print("📊 [DEBUG] Envelope Pearson correlation: \(String(format: "%.4f", envelopeScore))")

        // Method 2: RMS comparison (energy/loudness) - USE PROPER PEARSON CORRELATION
        let rms1 = calculateRMSWindows(array1)
        let rms2 = calculateRMSWindows(array2)

        guard rms1.count == rms2.count, !rms1.isEmpty else {
            print("📊 [DEBUG] RMS calculation failed, using envelope only")
            // Fallback to envelope only if RMS calculation fails
            let clampedScore = max(0, min(1, envelopeScore))
            let scaledScore = pow(clampedScore, 0.45)
            let finalScore = Double(scaledScore) * 100.0
            print("📊 [DEBUG] Final score (envelope only): \(String(format: "%.1f", finalScore))")
            return max(0, min(100, finalScore))
        }

        let rmsScore = pearsonCorrelation(rms1, rms2)

        print("📊 [DEBUG] RMS Pearson correlation: \(String(format: "%.4f", rmsScore))")

        // Combine both methods (75% envelope for shape, 25% energy - envelope more important for reversed audio)
        let combinedScore = (envelopeScore * 0.75) + (rmsScore * 0.25)

        print("📊 [DEBUG] Combined score (75/25): \(String(format: "%.4f", combinedScore))")

        // Clamp to [0, 1] range before scaling
        let clampedScore = max(0, min(1, combinedScore))

        // Apply gentle non-linear scaling (x^0.45 for subtle encouragement)
        // Examples: 100%→100%, 90%→95%, 80%→90%, 70%→85%, 60%→80%, 50%→73%
        let scaledSimilarity = pow(clampedScore, 0.45)

        print("📊 [DEBUG] After x^0.45 scaling: \(String(format: "%.4f", scaledSimilarity))")

        // Convert to 0-100 scale (no baseline boost - raw correlation determines score)
        let score = Double(scaledSimilarity) * 100.0

        print("📊 [DEBUG] Final score: \(String(format: "%.1f", score))")

        return max(0, min(100, score))
    }

    /// Calculate Pearson correlation coefficient (proper correlation, not just dot product)
    /// Returns value between -1 (inverse correlation) and 1 (perfect correlation)
    nonisolated private func pearsonCorrelation(_ x: [Float], _ y: [Float]) -> Float {
        guard x.count == y.count, !x.isEmpty else { return 0.0 }

        let n = Float(x.count)

        // Calculate means
        var meanX: Float = 0.0
        var meanY: Float = 0.0
        vDSP_meanv(x, 1, &meanX, vDSP_Length(x.count))
        vDSP_meanv(y, 1, &meanY, vDSP_Length(y.count))

        // Center the data (subtract mean)
        var centeredX = [Float](repeating: 0, count: x.count)
        var centeredY = [Float](repeating: 0, count: y.count)
        var negativeMeanX = -meanX
        var negativeMeanY = -meanY
        vDSP_vsadd(x, 1, &negativeMeanX, &centeredX, 1, vDSP_Length(x.count))
        vDSP_vsadd(y, 1, &negativeMeanY, &centeredY, 1, vDSP_Length(y.count))

        // Calculate covariance (sum of products)
        var covariance: Float = 0.0
        vDSP_dotpr(centeredX, 1, centeredY, 1, &covariance, vDSP_Length(x.count))

        // Calculate standard deviations
        var sumSquaredX: Float = 0.0
        var sumSquaredY: Float = 0.0
        vDSP_dotpr(centeredX, 1, centeredX, 1, &sumSquaredX, vDSP_Length(x.count))
        vDSP_dotpr(centeredY, 1, centeredY, 1, &sumSquaredY, vDSP_Length(y.count))

        let stdX = sqrt(sumSquaredX)
        let stdY = sqrt(sumSquaredY)

        // Avoid division by zero
        guard stdX > 0, stdY > 0 else { return 0.0 }

        // Pearson correlation coefficient
        let correlation = covariance / (stdX * stdY)

        // Return absolute value (we care about similarity, not direction)
        return abs(correlation)
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
