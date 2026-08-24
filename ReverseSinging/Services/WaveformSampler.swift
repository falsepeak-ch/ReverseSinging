//
//  WaveformSampler.swift
//  ReverseSinging
//
//  Reduces an audio file to a fixed number of peaks, for drawing
//

import AVFoundation

/// Turns an audio file into a small array of peaks, one per horizontal bar.
///
/// `WaveformView` elsewhere in the app is a live meter driven by the recorder's current
/// level; it cannot show a file that already exists. This is the other half: the shape of a
/// whole recording, so a take can be laid over the reference line and compared.
actor WaveformSampler {

    static let shared = WaveformSampler()

    /// Keyed by path and bucket count — the same file drawn at two widths is two results.
    private var cache: [String: [Float]] = [:]

    private init() {}

    /// Peaks for `url`, normalised to 0...1, one per bucket.
    ///
    /// Returns an empty array when the file can't be read, so a caller draws an empty rail
    /// rather than having to handle an error in the middle of a view body.
    func samples(from url: URL, buckets: Int = 96) async -> [Float] {
        guard buckets > 0 else { return [] }

        let key = "\(url.path)#\(buckets)"
        if let cached = cache[key] { return cached }

        let peaks = await Task.detached(priority: .userInitiated) {
            Self.computePeaks(from: url, buckets: buckets)
        }.value

        // Don't cache a failure: a take is sampled the moment it's written, and on a slow
        // device the file can still be settling.
        if !peaks.isEmpty { cache[key] = peaks }

        return peaks
    }

    /// Drops every cached shape for a file. Called when a take is re-recorded, otherwise the
    /// previous take's waveform would be drawn over the new one.
    func invalidate(_ url: URL) {
        let prefix = "\(url.path)#"
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    // MARK: - Sampling

    private nonisolated static func computePeaks(from url: URL, buckets: Int) -> [Float] {
        guard let buffer = try? DubAudioLoader.loadBuffer(from: url),
              let channels = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            return []
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let framesPerBucket = max(1, frameCount / buckets)

        var peaks = [Float](repeating: 0, count: buckets)
        var loudest: Float = 0

        for bucket in 0..<buckets {
            let start = bucket * framesPerBucket
            guard start < frameCount else { break }
            let end = min(start + framesPerBucket, frameCount)

            // Peak rather than RMS: speech is mostly quiet, and an RMS trace of a spoken
            // line reads as a flat smear where the peaks show the actual syllables.
            var peak: Float = 0
            for channel in 0..<channelCount {
                let samples = channels[channel]
                for frame in start..<end {
                    peak = max(peak, abs(samples[frame]))
                }
            }

            peaks[bucket] = peak
            loudest = max(loudest, peak)
        }

        // Normalise against the file's own loudest moment. A reference line mastered quietly
        // and a take shouted into a phone should be comparable in shape, not in absolute gain.
        guard loudest > 0 else { return peaks }
        return peaks.map { $0 / loudest }
    }
}

// MARK: - Resampling

enum WaveformScaling {

    /// How far past the reference a clip is allowed to be drawn, as a multiple of it.
    ///
    /// A take ten times the length of the line should read as "way too long" without asking
    /// the view to lay out thousands of bars, and without the live trace growing without
    /// bound while the mic stays open.
    static let maxOverrun = 3

    /// Bars a clip needs to sit on another clip's time axis.
    ///
    /// The comparison only means anything if both waveforms use the same seconds-per-bar.
    /// Sampling a long take into the reference's bar count would draw the two at identical
    /// widths and hide the very difference the overlay exists to show.
    static func bucketCount(
        forDuration duration: TimeInterval,
        referenceDuration: TimeInterval,
        referenceBuckets: Int
    ) -> Int {
        guard referenceDuration > 0, duration > 0 else { return 0 }
        let scaled = Double(referenceBuckets) * (duration / referenceDuration)
        return max(1, min(Int(scaled.rounded()), referenceBuckets * maxOverrun))
    }

    /// Squashes or stretches `values` to `count` entries by averaging each source span.
    /// Used for the live trace, which arrives as one entry per metering tick.
    static func resample(_ values: [Float], to count: Int) -> [Float] {
        guard count > 0 else { return [] }
        guard !values.isEmpty else { return [] }
        guard values.count != count else { return values }

        return (0..<count).map { index in
            let start = index * values.count / count
            let end = max(start + 1, (index + 1) * values.count / count)
            let span = values[start..<min(end, values.count)]
            guard !span.isEmpty else { return 0 }
            return span.reduce(0, +) / Float(span.count)
        }
    }
}
