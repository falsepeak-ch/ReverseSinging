//
//  DubVoiceLevel.swift
//  ReverseSinging
//
//  Brings a take up to the level of the line it replaces
//

import AVFoundation

/// Matches a take's loudness to the reference line it stands in for.
///
/// A take is recorded by whoever happens to be holding the phone, at whatever distance they
/// happen to hold it, in whatever room they are in. The film's dialogue was recorded and mixed
/// by people who did that for a living. Dropping one straight into the other's place leaves a
/// scene where every line arrives at a different volume — and where a take recorded politely
/// disappears under the music while the next one, shouted, jumps out of the speaker.
///
/// So each take is scaled to the level of the chunk it replaces. The film decides how loud the
/// dialogue in this scene is, which is the whole point: the result should sound like the scene,
/// not like a phone recording laid over one.
///
/// **Measured over the speech, not over the file.** A take with two seconds of nerves before
/// the first word has a low average across its whole length, and matching that average would
/// boost the words far past the original. Frames well below the take's own peak are left out
/// of the measurement, which is a crude voice-activity detector and is enough: the comparison
/// only has to be fair between two recordings of the same sentence.
///
/// **And matched only part of the way there, deliberately.** The reference is not the neutral
/// target it sounds like: the transfers these packs are cut from are heavily compressed, and
/// the starter scene's eighteen lines span three and a half decibels end to end. Matching a
/// take to that exactly does not make it sit in the scene, it irons the performance flat —
/// every line arriving at the same volume whether it was whispered or shouted, which is the
/// one thing an acted line must not do. `strength` closes most of the gap and leaves the rest,
/// so a take that was too quiet to hear comes up without a delivery being taken away from the
/// person who gave it.
nonisolated enum DubVoiceLevel {

    /// How much of the gap to the reference is closed, from 0 (leave the take alone) to 1
    /// (match it exactly).
    ///
    /// Two thirds of the difference, in decibels. Enough that a take recorded across the room
    /// stops disappearing, not so much that the scene's dynamics become the reference's — see
    /// the note above on how little range there is in one.
    static let strength: Float = 0.65

    /// How far a take may be moved, as linear gain. About 10 dB each way.
    ///
    /// Everything above the floor of a recording gets louder together, so a take that was
    /// barely audible cannot be matched without bringing the room up with it. Past this the
    /// cure is worse: the line arrives at the right level wrapped in hiss, and a take that
    /// quiet is one worth recording again.
    static let maximumBoost: Float = 3.2
    static let maximumCut: Float = 0.32

    /// Below this peak a buffer is treated as having nothing in it to measure.
    private static let silenceFloor: Float = 0.005

    /// Frames quieter than this fraction of the buffer's own peak are considered to be the
    /// gaps between words rather than the words.
    private static let speechFloor: Float = 0.1

    // MARK: - Measuring

    /// The RMS level of the speech in a buffer, or nil when there is nothing to measure.
    static func speechLevel(of buffer: AVAudioPCMBuffer) -> Float? {
        guard let samples = buffer.floatChannelData?[0] else { return nil }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return nil }

        var peak: Float = 0
        for frame in 0..<frames { peak = max(peak, abs(samples[frame])) }
        guard peak > silenceFloor else { return nil }

        let threshold = peak * speechFloor
        var sum: Double = 0
        var counted = 0

        for frame in 0..<frames where abs(samples[frame]) >= threshold {
            let sample = Double(samples[frame])
            sum += sample * sample
            counted += 1
        }

        guard counted > 0 else { return nil }
        return Float((sum / Double(counted)).squareRoot())
    }

    /// The gain that moves a take `strength` of the way to the reference's level, clamped.
    ///
    /// Raising the ratio to a power is what makes the fraction a fraction *in decibels*, which
    /// is the only scale on which "most of the way there" means anything to an ear.
    static func matchingGain(take: Float, reference: Float) -> Float {
        guard take > 0, reference > 0 else { return 1 }
        let corrected = powf(reference / take, strength)
        return min(maximumBoost, max(maximumCut, corrected))
    }

    // MARK: - Applying

    /// Scales `take` in place to sit at the reference's level.
    ///
    /// A no-op when either side has no speech to measure, so a caller can hand it a take that
    /// came out silent without checking first — an unmatched take is still a take, where one
    /// multiplied by a gain derived from silence would not be.
    @discardableResult
    static func match(_ take: AVAudioPCMBuffer, to reference: AVAudioPCMBuffer) -> Float {
        guard let takeLevel = speechLevel(of: take),
              let referenceLevel = speechLevel(of: reference) else { return 1 }

        let gain = matchingGain(take: takeLevel, reference: referenceLevel)
        guard gain != 1, let samples = take.floatChannelData?[0] else { return gain }

        for frame in 0..<Int(take.frameLength) {
            samples[frame] *= gain
        }
        return gain
    }

    /// Loads a line's reference and matches a take to it, when the reference can be read.
    ///
    /// The reference is decoded for this and thrown away. It costs a file read per line and is
    /// the only way to know what the film thought this line's level was; the alternative, a
    /// fixed target level for every take in every pack, would be the app deciding how loud a
    /// scene is instead of the scene deciding.
    static func match(_ take: AVAudioPCMBuffer, toReferenceAt url: URL) {
        guard let reference = try? DubAudioLoader.loadVoiceBuffer(from: url, applyFades: false) else { return }
        match(take, to: reference)
    }
}
