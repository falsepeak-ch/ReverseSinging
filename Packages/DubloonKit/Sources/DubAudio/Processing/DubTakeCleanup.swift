//
//  DubTakeCleanup.swift
//  DubAudio
//
//  Pushes the room down between the words of a take
//

public import AVFoundation

/// Holds down the quiet parts of a take, so a scene does not breathe between its lines.
///
/// A take is a whole line's worth of recording, and only part of it is speech. The rest is the
/// room: a fridge, a street, the phone's own preamp. On its own that is barely audible. Laid
/// end to end down a scene it is not, because **every take carries a different room**. Takes
/// recorded minutes apart in the same kitchen already differ by ten decibels or so, and the
/// level match that puts the voices at a consistent volume moves each take's room with it, so
/// two adjacent lines can arrive with noticeably different backgrounds. What you hear is not a
/// noisy recording, it is a noise floor that steps at every line boundary — and a step is far
/// easier to notice than the hiss itself.
///
/// So the non-speech parts of each take are pushed down before anything else touches them.
/// After this a take contributes almost nothing between its words, the steps have nothing left
/// to step between, and the scene sits still.
///
/// **An expander, not a gate.** A gate is a switch, and a switch on speech chatters on breaths
/// and chops the tails off words — which is a worse artefact than the one being fixed. This
/// leans on the quiet parts instead of cutting them, opens fast enough not to dull a
/// consonant, and closes slowly enough that a line still ends rather than stopping.
public enum DubTakeCleanup {

    /// Where each take's room is aimed, relative to its own speech. About 40 dB under.
    ///
    /// **A target, not a reduction.** Leaning on every take by the same number of decibels
    /// leaves the quiet recording quiet and the noisy one noisy, exactly as far apart as they
    /// started — which is the thing being fixed. Aiming them all at the same distance below
    /// their own voice is what closes the gap, and because the voices are then matched to each
    /// other too, the rooms end up matched as a consequence.
    public static let roomBelowSpeech: Float = 0.01

    /// The most this will lean on any one take, as a linear gain. About 24 dB.
    ///
    /// A take recorded somewhere genuinely loud cannot be brought all the way down to the
    /// target without the expander becoming audible as it works. Past this it stops trying and
    /// leaves the take a little noisier than the rest, which is the better of the two failures.
    public static let depth: Float = 0.06

    /// Where the expander starts working, as a multiple of the take's own noise floor.
    /// Roughly 10 dB above it: high enough to catch the room, low enough to leave a
    /// half-whispered syllable alone.
    public static let thresholdAboveFloor: Float = 3

    /// How much louder the speech has to be than the room before any of this is worth doing.
    ///
    /// About 12 dB. Below that the two are not separable, and an expander asked to separate
    /// them anyway takes lumps out of the words. A take recorded somewhere that loud is left
    /// exactly as it is.
    public static let minimumSeparation: Float = 4

    /// Open fast so a consonant is never dulled; close slowly so a word's tail is never cut.
    public static let attack: TimeInterval = 0.006
    public static let release: TimeInterval = 0.18

    /// How often the level is re-measured.
    public static let window: TimeInterval = 0.02

    // MARK: - Curve

    /// The gain the expander applies to each window of a take.
    ///
    /// Separated from the buffer so the shape can be read directly: a curve that dips into a
    /// word, or that never comes back up after one, is the whole failure mode here.
    public static func gains(for levels: [Float]) -> [Float] {
        guard !levels.isEmpty else { return [] }

        let sorted = levels.sorted()
        let floor = sorted[sorted.count / 10]
        let speech = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]

        // Nothing worth separating. The take is returned to full, unaltered.
        guard floor > 0, speech > floor * minimumSeparation else {
            return Array(repeating: 1, count: levels.count)
        }

        // How far this particular room has to come down to reach the target. A take that was
        // recorded somewhere quiet barely moves; one recorded in a kitchen moves a long way.
        let roomGain = min(1, max(depth, (speech * roomBelowSpeech) / floor))
        guard roomGain < 1 else { return Array(repeating: 1, count: levels.count) }

        let threshold = floor * thresholdAboveFloor
        let span = logf(threshold) - logf(floor)

        // Full reduction at the floor, none at the threshold, and a smooth ramp between the
        // two so a syllable trailing off is not stepped on halfway down.
        let targets = levels.map { level -> Float in
            guard level > 0 else { return roomGain }
            let above = span > 0 ? (logf(level) - logf(floor)) / span : 1
            return powf(roomGain, 1 - min(1, max(0, above)))
        }

        let hop = window
        let opening = Float(exp(-hop / attack))
        let closing = Float(exp(-hop / release))

        var gains = [Float](repeating: 1, count: levels.count)
        var current: Float = targets[0]

        for index in targets.indices {
            // One window of look-ahead, so the expander is already open when the first
            // sample of a word arrives rather than a window into it.
            let target = max(targets[index], index + 1 < targets.count ? targets[index + 1] : targets[index])
            let smoothing = target > current ? opening : closing
            current = target + (current - target) * smoothing
            gains[index] = current
        }

        return gains
    }

    // MARK: - Applying

    /// Measures a take and expands its quiet parts, in place.
    @discardableResult
    public static func apply(to buffer: AVAudioPCMBuffer) -> Bool {
        guard let samples = buffer.floatChannelData?[0] else { return false }

        let frames = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        let hop = max(1, Int(window * sampleRate))
        guard frames > hop * 4, sampleRate > 0 else { return false }

        var levels: [Float] = []
        levels.reserveCapacity(frames / hop)

        var start = 0
        while start + hop <= frames {
            var sum: Double = 0
            for frame in start..<(start + hop) {
                let sample = Double(samples[frame])
                sum += sample * sample
            }
            levels.append(Float((sum / Double(hop)).squareRoot()))
            start += hop
        }

        let gains = gains(for: levels)
        guard gains.contains(where: { $0 < 1 }) else { return false }

        // Interpolated between window centres, so the gain never steps within the take
        // either — a staircase at twenty milliseconds is its own kind of noise.
        for index in gains.indices {
            let from = gains[index]
            let to = index + 1 < gains.count ? gains[index + 1] : gains[index]
            let first = index * hop
            let last = min(frames, first + hop)

            for frame in first..<last {
                let progress = Float(frame - first) / Float(hop)
                samples[frame] *= from + (to - from) * progress
            }
        }

        // Whatever is left past the last whole window keeps the final gain.
        if let last = gains.last, gains.count * hop < frames {
            for frame in (gains.count * hop)..<frames {
                samples[frame] *= last
            }
        }

        return true
    }
}
