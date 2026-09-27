//
//  ImitationScorer.swift
//  DubScoring
//
//  Measuring an impression against the sound it imitates
//

@preconcurrency public import AVFoundation
import Accelerate
import DubAudio

/// Scores someone's impression of a sound (a meow, a siren, a laser) against the sound itself.
///
/// ## Why neither of the other scorers will do
///
/// `AudioSimilarityCalculator` and `DubScorer` only look at loudness over time. That is right
/// for their games and blind for this one: a siren's wail and a cow's moo can have the same
/// loudness shape, and what makes an impression of either land is the *note moving*. So this
/// scorer follows three things over time:
///
/// - **Loudness** (rhythm): the bursts and gaps, the swell and the tail.
/// - **Pitch contour**: in semitones relative to each clip's own median, so a deep voice
///   doing a high cat is judged on the shape of the meow, not on being a deep voice.
/// - **Brightness** (spectral centroid): hissy or hummed. Compared as a shape plus a loose
///   level, because a voice can get near a sneeze's hiss but never near a real horn's brass.
///
/// And because nobody performs at exactly the recording's speed, each contour is compared
/// after dynamic time warping, inside a band that allows a quarter of the length's worth of
/// drift. Enough to forgive a slow start, not enough to make any two sounds match.
public enum ImitationScorer {

    // MARK: - Tuning

    /// Analysis runs at this rate: plenty for a voice's pitch and brightness, and four times
    /// cheaper than the file's own.
    static let analysisRate: Double = 22_050

    /// Seconds between analysis frames.
    static let hop: TimeInterval = 0.02

    /// Samples per analysis window. Long enough to hold a few periods of a low voice.
    static let window = 1024

    /// Pitch search range, Hz. A growl to a whistle.
    static let lowestPitch: Double = 65
    static let highestPitch: Double = 1_100

    /// YIN's aperiodicity threshold. Below it a frame is called pitched.
    static let voicingThreshold: Float = 0.2

    /// Frame loudness, relative to the clip's peak, above which something is happening.
    static let activityFloor: Float = 0.06

    /// Below this peak (about -40 dBFS) a take is treated as nothing recorded.
    static let silencePeak: Float = 0.01

    // MARK: - Scoring

    /// Scores the take at `takeURL` against the sound at `referenceURL`.
    ///
    /// - Returns: nil when either file can't be read. A silent take scores `.silent`.
    public static func score(takeURL: URL, referenceURL: URL) -> ImitationScore? {
        guard let take = try? DubAudioLoader.loadVoiceBuffer(from: takeURL, applyFades: false),
              let reference = try? DubAudioLoader.loadVoiceBuffer(from: referenceURL, applyFades: false)
        else { return nil }

        return score(take: take, reference: reference)
    }

    /// The measurement itself, on buffers in `DubAudioLoader.canonicalFormat` (or any mono
    /// float buffer).
    public static func score(take: AVAudioPCMBuffer, reference: AVAudioPCMBuffer) -> ImitationScore? {
        let referenceSamples = samples(of: reference)
        guard let referenceFeatures = features(of: referenceSamples, sampleRate: reference.format.sampleRate)
        else { return nil }

        let takeSamples = samples(of: take)
        guard let takeFeatures = features(of: takeSamples, sampleRate: take.format.sampleRate)
        else { return .silent }

        return compare(takeFeatures, referenceFeatures)
    }

    // MARK: - Comparison

    static func compare(_ take: Features, _ reference: Features) -> ImitationScore {
        let rhythm = rhythmScore(take.loudness, reference.loudness)
        let pitch = pitchScore(take, reference)
        let tone = toneScore(take, reference)
        let duration = durationScore(take.duration, reference.duration)
        return ImitationScore(rhythm: rhythm, pitch: pitch, tone: tone, duration: duration)
    }

    /// Loudness contours on a 40 dB scale, warped together. Scale-free, so a shout and a
    /// whisper with the same shape score the same.
    private static func rhythmScore(_ take: [Float], _ reference: [Float]) -> Double {
        let cost = DynamicTimeWarping.averageCost(standardised(take), standardised(reference))
        return similarity(cost: cost, zeroAt: 0.6)
    }

    /// Nil when the sound has no pitch worth following. Zero when it does and the take
    /// never found a note.
    private static func pitchScore(_ take: Features, _ reference: Features) -> Double? {
        guard reference.voicedFraction >= 0.3 else { return nil }

        let referenceContour = reference.relativePitch
        let takeContour = take.relativePitch
        guard referenceContour.count >= 3, takeContour.count >= 3 else { return 0 }

        // Semitones are already on a scale that means something, so no standardising: a take
        // that sweeps half as far as a siren is half-way to right, not the same shape.
        let cost = DynamicTimeWarping.averageCost(
            takeContour.map { min(max($0, -18), 18) },
            referenceContour.map { min(max($0, -18), 18) }
        )
        let shape = similarity(cost: cost, zeroAt: 3)

        // How far the note travels at all. A flat honk and a meow can hover around the same
        // median closely enough to pass the shape test; they can't have the same range.
        let takeRange = max(1, spread(takeContour))
        let referenceRange = max(1, spread(referenceContour))
        let range = 100 * Double(min(takeRange, referenceRange) / max(takeRange, referenceRange))

        // Roughly where the note sits. Nobody's voice reaches a real cat or a real horn, so a
        // whole octave either side is fine; it only has to tell a cat from a cow.
        let gap = abs(take.register - reference.register)
        let register = 100 * Double(max(0, 1 - max(0, gap - 1) / 1.5))

        // Range and register only temper a contour that already matches; the note going the
        // wrong way is wrong however well it is pitched.
        return shape * (0.5 + 0.3 * range / 100 + 0.2 * register / 100)
    }

    /// The brightness shape, a loose check on brightness level, and whether the sound is
    /// pitched or noisy in about the same proportion.
    private static func toneScore(_ take: Features, _ reference: Features) -> Double {
        let shapeCost = DynamicTimeWarping.averageCost(
            standardised(take.brightness), standardised(reference.brightness)
        )
        let shape = similarity(cost: shapeCost, zeroAt: 0.7)

        // Median brightness in octaves. Inside half an octave is as close as a voice gets.
        let gap = abs(median(take.brightness) - median(reference.brightness))
        let level = 100 * Double(max(0, 1 - max(0, gap - 0.5) / 1.0))

        let character = 100 * (1 - abs(take.voicedFraction - reference.voicedFraction))

        return shape * 0.45 + level * 0.30 + character * 0.25
    }

    /// Full marks inside 10% of the length, nothing at half of it or less.
    private static func durationScore(_ take: TimeInterval, _ reference: TimeInterval) -> Double {
        guard take > 0, reference > 0 else { return 0 }
        let ratio = min(take, reference) / max(take, reference)
        return 100 * min(1, max(0, (ratio - 0.5) / 0.4))
    }

    /// Average warped distance → 0...100, linearly, reaching zero at `zeroAt`.
    private static func similarity(cost: Float, zeroAt: Float) -> Double {
        guard cost.isFinite else { return 0 }
        return 100 * Double(max(0, 1 - cost / zeroAt))
    }

    // MARK: - Features

    /// What the comparison needs from one clip, over its active stretch only.
    struct Features {
        /// Loudness per frame in dB, clamped to 40 dB under the clip's peak.
        var loudness: [Float]
        /// Semitones from the clip's median pitch, for the pitched frames, in order.
        var relativePitch: [Float]
        /// The median pitch in octaves (log2 Hz), 0 when nothing was pitched.
        var register: Float
        /// Spectral centroid per frame, in octaves (log2 Hz).
        var brightness: [Float]
        /// Share of active frames that carried a pitch.
        var voicedFraction: Double
        /// Seconds from the first active frame to the last.
        var duration: TimeInterval
    }

    /// Nil when there's nothing in the clip to measure.
    static func features(of input: [Float], sampleRate: Double) -> Features? {
        let signal = resample(input, from: sampleRate)
        guard signal.count > window,
              let peak = signal.map(abs).max(), peak >= silencePeak
        else { return nil }

        let hopSize = Int(hop * analysisRate)
        let frameCount = (signal.count - window) / hopSize + 1

        var energy = [Float](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            let start = frame * hopSize
            energy[frame] = vDSP.rootMeanSquare(signal[start..<(start + window)])
        }
        guard let loudest = energy.max(), loudest > 0 else { return nil }
        let relative = energy.map { $0 / loudest }

        // The stretch between the first and the last frame with anything in it; the silence
        // either side of an impression is the phone's, not the performer's.
        guard let first = relative.firstIndex(where: { $0 > activityFloor }),
              let last = relative.lastIndex(where: { $0 > activityFloor }),
              last > first
        else { return nil }

        let dft = try? vDSP.DiscreteFourierTransform(
            count: window, direction: .forward, transformType: .complexComplex, ofType: Float.self
        )
        let hann = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: window, isHalfWindow: false)
        let zeros = [Float](repeating: 0, count: window)
        let binWidth = Float(analysisRate) / Float(window)

        var loudness: [Float] = []
        var pitches: [Float] = []
        var brightness: [Float] = []
        var activeFrames = 0

        for frame in first...last {
            let start = frame * hopSize
            let slice = Array(signal[start..<(start + window)])

            loudness.append(max(-40, 20 * log10(max(relative[frame], 1e-6))))

            guard relative[frame] > activityFloor else { continue }
            activeFrames += 1

            if let hz = pitch(in: signal, at: start) { pitches.append(Float(hz)) }

            if let dft {
                let windowed = vDSP.multiply(slice, hann)
                let (real, imaginary) = dft.transform(real: windowed, imaginary: zeros)
                let half = window / 2
                var magnitudes = [Float](repeating: 0, count: half)
                for bin in 1..<half {
                    magnitudes[bin] = (real[bin] * real[bin] + imaginary[bin] * imaginary[bin]).squareRoot()
                }
                let total = vDSP.sum(magnitudes)
                if total > 0 {
                    var weighted: Float = 0
                    for bin in 1..<half { weighted += Float(bin) * binWidth * magnitudes[bin] }
                    brightness.append(log2(max(weighted / total, 50)))
                }
            }
        }

        let medianPitch = median(pitches)
        let relativePitch = smoothed(pitches.map { 12 * log2($0 / medianPitch) })

        return Features(
            loudness: loudness,
            relativePitch: medianPitch > 0 ? relativePitch : [],
            register: medianPitch > 0 ? log2(medianPitch) : 0,
            brightness: brightness,
            voicedFraction: activeFrames > 0 ? Double(pitches.count) / Double(activeFrames) : 0,
            duration: Double(last - first) * hop
        )
    }

    /// YIN: the lag at which the signal best repeats itself, if it repeats well enough to
    /// call it a note.
    static func pitch(in signal: [Float], at start: Int) -> Double? {
        let minLag = Int(analysisRate / highestPitch)
        let maxLag = Int(analysisRate / lowestPitch)
        guard start + window + maxLag <= signal.count else { return nil }

        let base = signal[start..<(start + window)]
        var cumulative: Float = 0
        var normalised = [Float](repeating: 1, count: maxLag + 1)

        for lag in 1...maxLag {
            let shifted = signal[(start + lag)..<(start + lag + window)]
            let difference = vDSP.distanceSquared(base, shifted)
            cumulative += difference
            normalised[lag] = cumulative > 0 ? difference * Float(lag) / cumulative : 1
        }

        // First dip under the threshold, followed down to its own minimum.
        var lag = minLag
        while lag <= maxLag, normalised[lag] >= voicingThreshold { lag += 1 }
        guard lag <= maxLag else { return nil }
        while lag + 1 <= maxLag, normalised[lag + 1] < normalised[lag] { lag += 1 }

        return analysisRate / Double(lag)
    }

    // MARK: - Helpers

    private static func samples(of buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
    }

    /// Down to `analysisRate` by averaging, which doubles as a crude low-pass.
    private static func resample(_ input: [Float], from sampleRate: Double) -> [Float] {
        let factor = max(1, Int((sampleRate / analysisRate).rounded()))
        guard factor > 1 else { return input }

        let count = input.count / factor
        var output = [Float](repeating: 0, count: count)
        input.withUnsafeBufferPointer { source in
            for index in 0..<count {
                var sum: Float = 0
                for offset in 0..<factor { sum += source[index * factor + offset] }
                output[index] = sum / Float(factor)
            }
        }
        return output
    }

    /// Zero mean, unit spread. A contour that barely moves stays flat rather than having its
    /// noise blown up into a shape.
    static func standardised(_ values: [Float]) -> [Float] {
        guard values.count > 1 else { return values.map { _ in 0 } }
        let mean = vDSP.mean(values)
        let centred = vDSP.add(-mean, values)
        let spread = (vDSP.sumOfSquares(centred) / Float(values.count)).squareRoot()
        guard spread > 0.05 else { return centred.map { _ in 0 } }
        return vDSP.divide(centred, spread)
    }

    /// A five-frame median filter with octave errors folded back: YIN now and then locks onto
    /// a harmonic for a frame or three, which would otherwise read as a leap of an octave.
    static func smoothed(_ contour: [Float]) -> [Float] {
        guard contour.count >= 5 else { return contour }
        var folded = contour
        for index in folded.indices {
            let neighbourhood = contour[max(0, index - 3)...min(contour.count - 1, index + 3)]
            let local = median(Array(neighbourhood))
            while folded[index] - local > 9 { folded[index] -= 12 }
            while local - folded[index] > 9 { folded[index] += 12 }
        }
        return folded.indices.map { index in
            median(Array(folded[max(0, index - 2)...min(folded.count - 1, index + 2)]))
        }
    }

    /// The 10th to the 90th percentile: how far a contour travels, ignoring stray frames.
    static func spread(_ values: [Float]) -> Float {
        guard values.count > 2 else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count * 9 / 10] - sorted[sorted.count / 10]
    }

    static func median(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}

/// Dynamic time warping over two contours, within a Sakoe–Chiba band.
enum DynamicTimeWarping {

    /// Mean absolute difference along the cheapest alignment, per step of the path.
    ///
    /// The band is a quarter of the longer contour, widened to at least cover the difference
    /// in length. Infinity for empty input.
    static func averageCost(_ a: [Float], _ b: [Float]) -> Float {
        let n = a.count, m = b.count
        guard n > 0, m > 0 else { return .infinity }

        let band = max(abs(n - m) + 1, max(n, m) / 4)
        let infinity = Float.infinity

        // Cost and path length, row by row.
        var previous = [(cost: Float, steps: Int)](repeating: (infinity, 0), count: m + 1)
        var current = previous
        previous[0] = (0, 0)

        for i in 1...n {
            current[0] = (infinity, 0)
            let centre = Int((Double(i) * Double(m) / Double(n)).rounded())
            let lower = max(1, centre - band)
            let upper = min(m, centre + band)
            for j in 1...m { current[j] = (infinity, 0) }
            if lower <= upper {
                for j in lower...upper {
                    let distance = abs(a[i - 1] - b[j - 1])
                    let candidates = [previous[j - 1], previous[j], current[j - 1]]
                    let best = candidates.min { $0.cost < $1.cost }!
                    if best.cost.isFinite {
                        current[j] = (best.cost + distance, best.steps + 1)
                    }
                }
            }
            swap(&previous, &current)
        }

        let end = previous[m]
        guard end.cost.isFinite, end.steps > 0 else { return .infinity }
        return end.cost / Float(end.steps)
    }
}
