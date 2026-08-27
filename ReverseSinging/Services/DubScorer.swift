//
//  DubScorer.swift
//  ReverseSinging
//
//  Measuring a take against the line it replaces
//

@preconcurrency import AVFoundation

/// Scores a take against the pack's own recording of the same line.
///
/// ## What is being measured, and why not just "how similar do these sound"
///
/// The reverse-singing game asks whether two recordings of the *same* audio resemble each
/// other, so raw waveform correlation is a fair question there. A dub is a different game: the
/// user says the same words in their own voice, in their own register, through a phone mic, over
/// a line recorded on a film set. Two takes that are both perfect dubs can look nothing alike
/// sample for sample. Comparing them directly would score the timbre of someone's voice, which
/// is not something they can practise and not something the game is about.
///
/// What a dub *is* about is whether the words land on the mouth. So all three measures are
/// taken from the energy envelope. Where sound is and isn't, and how much of it there is,
/// and none of them looks at pitch or timbre at all:
///
/// - **Timing**: how far your first word is from theirs. The single thing that makes a dub
///   read as a dub.
/// - **Pacing**: with both lined up at that first word, do the syllables in between fall
///   together? This is what catches a read that starts right and then rushes.
/// - **Delivery**: does the loudness rise and fall where theirs does, the shouted word
///   shouted, the muttered one muttered.
///
/// Scored against the raw take, before `DubVoiceAlignment` nudges it into place. The mix
/// forgives a late entry so the finished scene sounds good; the score is where the user is
/// told they were late.
nonisolated enum DubScorer {

    // MARK: - Tuning

    /// Seconds per envelope frame. Roughly a syllable's worth of speech, fine enough to see
    /// individual words, coarse enough that the score isn't measuring glottal noise.
    private static let frameDuration: TimeInterval = 0.02

    /// Being inside this of the original's entry is as good as being on it.
    ///
    /// Human hearing tolerates a fair amount of lip-sync error, and a phone's own record
    /// latency eats part of the budget before the performer does anything. Anything tighter
    /// would score the hardware.
    private static let perfectTiming: TimeInterval = 0.08

    /// Past this, the entry has missed. A quarter of a second late is visible on a face.
    private static let missedTiming: TimeInterval = 0.9

    /// Envelope level, relative to the clip's own peak, above which we call it speech.
    /// The same floor `DubSpeechOnset` uses, so "where the speech is" means one thing.
    private static let speechFloor: Float = 0.04

    // MARK: - Scoring

    /// Scores the take at `takeURL` against the reference for `line`.
    ///
    /// Returns nil when either file is missing or unreadable. A scoreless line reads as
    /// "not measured", which is honest, rather than as a zero the user did not earn.
    static func score(takeURL: URL, referenceURL: URL, line: DubLine) -> DubLineScore? {
        guard let take = try? DubAudioLoader.loadVoiceBuffer(from: takeURL, applyFades: false),
              let reference = try? DubAudioLoader.loadVoiceBuffer(from: referenceURL, applyFades: false)
        else { return nil }

        return score(take: take, reference: reference, line: line)
    }

    /// The measurement itself, on buffers already in `DubAudioLoader.canonicalFormat`.
    static func score(take: AVAudioPCMBuffer, reference: AVAudioPCMBuffer, line: DubLine) -> DubLineScore? {
        let takeEnvelope = envelope(of: take)
        let referenceEnvelope = envelope(of: reference)

        guard !takeEnvelope.isEmpty, !referenceEnvelope.isEmpty else { return nil }

        // A take with nothing in it is not a performance to score. Told apart from a quiet
        // one by its own peak: everything downstream is peak-relative, so a silent buffer
        // would otherwise normalise its noise floor up into a plausible-looking shape.
        guard peak(of: take) > 0, peak(of: reference) > 0 else {
            return DubLineScore(slug: line.slug, timing: 0, pacing: 0, delivery: 0)
        }

        // The original's entry is already known from import; the take's is measured here.
        // Both are offsets into their own clip, which is what makes them comparable.
        let referenceOnset = line.speech?.start ?? firstSpeechFrame(referenceEnvelope).map(seconds) ?? 0
        let takeOnset = firstSpeechFrame(takeEnvelope).map(seconds) ?? 0

        let timing = timingScore(takeOnset: takeOnset, referenceOnset: referenceOnset)

        // Lined up on the entry, so pacing and delivery judge what happened *after* coming
        // in, otherwise a late take would be marked down three times for one mistake.
        let alignedTake = dropping(takeEnvelope, seconds: takeOnset)
        let alignedReference = dropping(referenceEnvelope, seconds: referenceOnset)

        let pacing = pacingScore(alignedTake, alignedReference)
        let delivery = deliveryScore(alignedTake, alignedReference)

        return DubLineScore(slug: line.slug, timing: timing, pacing: pacing, delivery: delivery)
    }

    // MARK: - Timing

    /// Full marks inside `perfectTiming`, nothing past `missedTiming`, and a curve between.
    ///
    /// The curve is deliberately gentle near the top and steep in the middle: the difference
    /// between 50 ms and 100 ms out is not something a viewer can see, whereas the difference
    /// between 300 ms and 500 ms is the difference between "slightly off" and "dubbed badly".
    static func timingScore(takeOnset: TimeInterval, referenceOnset: TimeInterval) -> Double {
        let error = abs(takeOnset - referenceOnset)

        if error <= perfectTiming { return 100 }
        if error >= missedTiming { return 0 }

        let overshoot = (error - perfectTiming) / (missedTiming - perfectTiming)
        return 100 * (1 - overshoot * overshoot)
    }

    // MARK: - Pacing

    /// How well the two energy shapes line up once both start at their first word.
    ///
    /// Correlation over the stretch they share, so a take that stops early is judged on what
    /// it did say and then marked down for the length it didn't, rather than being compared
    /// against silence and scoring well for it.
    private static func pacingScore(_ take: [Float], _ reference: [Float]) -> Double {
        let shared = min(take.count, reference.count)
        guard shared > 1 else { return 0 }

        let correlation = pearson(Array(take.prefix(shared)), Array(reference.prefix(shared)))

        // Correlation runs -1...1 and anything at or below zero is "no relationship", which
        // for this purpose is the floor rather than something to distinguish between.
        let shape = Double(max(0, correlation))

        // How much of the longer clip the two actually have in common. A one-second answer to
        // a four-second line correlates beautifully over its second and is still wrong.
        let longest = max(take.count, reference.count)
        let coverage = Double(shared) / Double(longest)

        return 100 * shape * coverage
    }

    // MARK: - Delivery

    /// Whether the loudness rises and falls the way the original's does.
    ///
    /// Two things have to agree: the *shape* of the contour, and how much of a contour there
    /// is at all. A take read flat can still correlate with an expressive original if its tiny
    /// wobbles happen to line up, so the dynamic range is scored alongside the shape, you
    /// have to both go up in the right places and actually go up.
    private static func deliveryScore(_ take: [Float], _ reference: [Float]) -> Double {
        let shared = min(take.count, reference.count)
        guard shared > 1 else { return 0 }

        let takeLoud = loudnessContour(Array(take.prefix(shared)))
        let referenceLoud = loudnessContour(Array(reference.prefix(shared)))

        let shape = Double(max(0, pearson(takeLoud, referenceLoud)))

        let takeRange = dynamicRange(takeLoud)
        let referenceRange = dynamicRange(referenceLoud)

        // Ratio of the smaller range to the larger: 1 when the two are equally expressive,
        // falling away whether the take is flatter than the original or wilder than it.
        let expressiveness: Double
        if referenceRange <= 0 && takeRange <= 0 {
            expressiveness = 1
        } else {
            expressiveness = Double(min(takeRange, referenceRange) / max(takeRange, referenceRange, 0.0001))
        }

        return 100 * (shape * 0.65 + expressiveness * 0.35)
    }

    /// The contour on a decibel-ish scale, so a change from quiet to slightly-less-quiet
    /// counts for as much as the same change at the top. Which is how it is heard.
    private static func loudnessContour(_ envelope: [Float]) -> [Float] {
        envelope.map { log10(max($0, 0.0005)) }
    }

    private static func dynamicRange(_ contour: [Float]) -> Float {
        guard let low = contour.min(), let high = contour.max() else { return 0 }
        return high - low
    }

    // MARK: - Envelope

    /// Peak-normalised RMS per frame.
    ///
    /// Normalising against the clip's own loudest moment is what lets a reference mastered for
    /// a cinema and a take shouted into a phone be compared at all, every measure downstream
    /// is about the shape, never the absolute level.
    static func envelope(of buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return [] }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let window = max(1, Int(frameDuration * buffer.format.sampleRate))

        var envelope: [Float] = []
        envelope.reserveCapacity(frameCount / window + 1)

        var start = 0
        while start < frameCount {
            let end = min(start + window, frameCount)
            var sumOfSquares: Float = 0

            for channel in 0..<channelCount {
                let samples = channels[channel]
                for frame in start..<end {
                    sumOfSquares += samples[frame] * samples[frame]
                }
            }

            let count = Float((end - start) * channelCount)
            envelope.append((sumOfSquares / count).squareRoot())
            start += window
        }

        guard let loudest = envelope.max(), loudest > 0 else { return envelope }
        return envelope.map { $0 / loudest }
    }

    private static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }

        var peak: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            let samples = channels[channel]
            for frame in 0..<Int(buffer.frameLength) { peak = max(peak, abs(samples[frame])) }
        }
        return peak
    }

    private static func firstSpeechFrame(_ envelope: [Float]) -> Int? {
        envelope.firstIndex { $0 > speechFloor }
    }

    private static func seconds(_ frame: Int) -> TimeInterval {
        Double(frame) * frameDuration
    }

    private static func dropping(_ envelope: [Float], seconds: TimeInterval) -> [Float] {
        let frames = max(0, Int((seconds / frameDuration).rounded()))
        guard frames < envelope.count else { return [] }
        return Array(envelope[frames...])
    }

    // MARK: - Statistics

    /// Pearson correlation, -1...1. Zero for a constant series, where "how do these two vary
    /// together" has no answer.
    static func pearson(_ x: [Float], _ y: [Float]) -> Float {
        guard x.count == y.count, x.count > 1 else { return 0 }

        let count = Float(x.count)
        let meanX = x.reduce(0, +) / count
        let meanY = y.reduce(0, +) / count

        var covariance: Float = 0
        var varianceX: Float = 0
        var varianceY: Float = 0

        for index in x.indices {
            let dx = x[index] - meanX
            let dy = y[index] - meanY
            covariance += dx * dy
            varianceX += dx * dx
            varianceY += dy * dy
        }

        guard varianceX > 0, varianceY > 0 else { return 0 }
        return covariance / (varianceX * varianceY).squareRoot()
    }
}
