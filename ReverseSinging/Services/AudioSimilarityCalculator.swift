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

        // Large moving average for smoothing (window = 150 samples, less sensitive to timing)
        let windowSize = 150

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
        let windowSize = 250 // Large energy window (more forgiving of timing differences)

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
        // Filter out silence/low sounds FIRST (gentle 10% threshold)
        let filtered1 = filterSignificantSounds(array1)
        let filtered2 = filterSignificantSounds(array2)

        let minLength = min(filtered1.count, filtered2.count)

        // Trim both to same length
        let trimmed1 = Array(filtered1.prefix(minLength))
        let trimmed2 = Array(filtered2.prefix(minLength))

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

        // Method 1: Envelope comparison (shape)
        let envelope1 = extractEnvelope(array1)
        let envelope2 = extractEnvelope(array2)

        var envelopeCorrelation: Float = 0.0
        vDSP_dotpr(envelope1, 1, envelope2, 1, &envelopeCorrelation, vDSP_Length(envelope1.count))
        let envelopeScore = abs(envelopeCorrelation / Float(envelope1.count))

        // Method 2: RMS comparison (energy/loudness)
        let rms1 = calculateRMSWindows(array1)
        let rms2 = calculateRMSWindows(array2)

        guard rms1.count == rms2.count, !rms1.isEmpty else {
            // Fallback to envelope only if RMS calculation fails
            let scaledScore = pow(envelopeScore, 0.2)
            return Double(scaledScore) * 100.0
        }

        var rmsCorrelation: Float = 0.0
        vDSP_dotpr(rms1, 1, rms2, 1, &rmsCorrelation, vDSP_Length(rms1.count))
        let rmsScore = abs(rmsCorrelation / Float(rms1.count))

        // Combine both methods (75% envelope for shape, 25% energy - envelope more important for reversed audio)
        let combinedScore = (envelopeScore * 0.75) + (rmsScore * 0.25)

        // Apply ULTRA forgiving non-linear scaling (x^0.15 for maximum encouragement)
        // Examples with baseline: 30% → 68, 40% → 74, 50% → 79, 60% → 83, 70% → 87, 80% → 90
        let scaledSimilarity = pow(combinedScore, 0.15)

        // Convert to 0-100 scale with baseline boost (15 base + 85 scaled)
        // Everyone gets 15 points for trying, remaining 85 points based on similarity
        let score = Double(scaledSimilarity) * 85.0 + 15.0

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
