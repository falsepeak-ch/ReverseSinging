//
//  DubBackingBalance.swift
//  ReverseSinging
//
//  Where a pack's backing track sits under the dialogue over it
//

import AVFoundation

/// Sets a pack's backing track to one level for the whole scene.
///
/// A backing track is music and effects, and it arrives at whatever level whoever cut the pack
/// happened to have it at. A scene cut from a 1951 educational short ships its bed nearly
/// thirty decibels under its own dialogue; one cut from a feature ships the music and effects
/// stem level with it. So the level cannot be a fixed number — the same multiplier lands those
/// two in completely different places, and one of the two is always wrong. The scene's own
/// dialogue is measured first and the bed is placed under *that*, which is the only way the
/// result is the same shape whatever the pack.
///
/// **One gain, applied once, held for the whole scene.** Nothing here moves with the audio:
/// the bed is dimmed by the same amount at every moment, and whatever dynamics the film gave
/// it — including the dip most packs print under each line — are its own to keep. Three
/// other designs were tried and every one was worse than a bed that is simply a bit loud:
///
/// - Ducking the bed under each line. A duck is only audible when it moves, so the fix for
///   "too loud" arrives as "won't sit still", and on a scored scene the score is heard
///   changing volume every time somebody speaks.
/// - Levelling the bed against itself before placing it, to undo the printed dip. Any
///   leveller fast enough to undo a dip the length of a line is a compressor, and a
///   compressor on a music bed breathes with the music: measured on a feature cut, it swung
///   the bed 14 dB inside a single second and dragged a quiet passage up by 17 dB.
/// - Holding the gaps between lines down to the level under them, so the dip's edges do not
///   show. Measurably the most continuous, and still wrong: it is a ceiling on the bed, and
///   a swell that the film plays at full is heard being held back. A constant dim is what
///   was asked for, and it is the only one of the four that never does anything by itself.
///
/// **Measured under the lines, not across the file.** What matters is how loud the bed is
/// while somebody is speaking over it, and that is where most packs are already quietest: a
/// bed taken out of a finished mix carries the film's own duck. Measuring the whole file
/// would count the roar between two lines and turn the bed down for a moment nobody speaks
/// over. Measuring under the lines respects the duck the pack arrived with instead of
/// stacking another one on top of it.
///
/// **Only under a dub.** This exists for the takes, which carry a voice and nothing else.
/// The film's own reference chunks are cut from its finished mix and carry its music and
/// effects with them, and a pack's bed is dipped under each line precisely so that chunk
/// plus bed adds back up to the film. Playing the original through this balance breaks that
/// sum — the bed ends up a dozen decibels under the chunk's own ambience, and every line
/// start is heard as the room jumping up. The original plays over the bed untouched.
nonisolated enum DubBackingBalance {

    /// The bed's gain under the film's own dialogue: unity, because the pack was cut so
    /// that its chunks and its bed reconstruct the film at exactly that level. Measured on a
    /// feature cut, the reconstruction tracks the original mix within a couple of decibels
    /// across every line boundary; at three-quarters, what the app used for years, it sits
    /// a step under.
    static let originalBedGain: Float = 1

    /// Where the bed sits under the scene's dialogue, in decibels, while a line is playing.
    ///
    /// Twelve under. Enough that a take recorded on a phone, which has none of the presence a
    /// film's dialogue was mixed with, is never in question; not so far that the score stops
    /// being part of the scene. **This is the number to change if the balance is wrong** —
    /// more negative for a bed further back, less for one more present.
    static let bedBelowDialogue: Float = -12

    /// Where the bed is left when neither side can be measured: the level every export used
    /// before any of this was measured, so a pack with nothing to measure sounds as it did.
    static let fallbackBedGain: Float = 0.75

    /// The bed is never boosted, and never taken so far down it stops being part of the scene.
    ///
    /// Never above unity: a pack whose bed already sits politely under its dialogue is one
    /// somebody balanced on the way in, and turning it up would be the app overruling them.
    static let maximumBedGain: Float = 1
    /// About 20 dB of cut. A bed that needs more than that to sit under the dialogue is one
    /// the pack cut louder than its own film, and past this the scene has no ambience left.
    static let minimumBedGain: Float = 0.1

    // MARK: - Measuring

    /// How loud this scene's dialogue is, from the film's own recording of it.
    ///
    /// The median rather than the mean: a scene that ends on a whisper, or opens on a shout,
    /// should not drag the level every other line is judged against with it.
    static func dialogueLevel(of pack: DubPack) -> Float? {
        let levels = pack.lines.compactMap { line -> Float? in
            guard let buffer = try? DubAudioLoader.loadVoiceBuffer(
                from: pack.referenceAudioURL(for: line),
                applyFades: false
            ) else { return nil }
            return DubVoiceLevel.speechLevel(of: buffer)
        }

        guard !levels.isEmpty else { return nil }
        return levels.sorted()[levels.count / 2]
    }

    /// How loud the bed is while the lines play over it: the median of its level under each.
    ///
    /// Plain RMS over each line's stretch, every channel. Nothing is gated out here, because
    /// a bed that is near-silent under a line really is that quiet under it, and that is
    /// exactly what should count.
    static func bedLevel(of bed: AVAudioPCMBuffer, under lines: [DubLine]) -> Float? {
        guard let channels = bed.floatChannelData else { return nil }

        let sampleRate = bed.format.sampleRate
        let channelCount = Int(bed.format.channelCount)
        let frames = Int(bed.frameLength)
        guard sampleRate > 0, channelCount > 0, frames > 0 else { return nil }

        let levels = lines.compactMap { line -> Float? in
            let first = max(0, Int(line.startTime * sampleRate))
            let last = min(frames, Int(line.endTime * sampleRate))
            guard last > first else { return nil }

            var sum: Double = 0
            for channel in 0..<channelCount {
                let samples = channels[channel]
                for frame in first..<last {
                    let sample = Double(samples[frame])
                    sum += sample * sample
                }
            }
            return Float((sum / Double((last - first) * channelCount)).squareRoot())
        }

        guard !levels.isEmpty else { return nil }
        return levels.sorted()[levels.count / 2]
    }

    // MARK: - Placing

    /// The gain that puts a bed at `bed` under dialogue at `dialogue` by `bedBelowDialogue`.
    static func bedGain(bed: Float?, dialogue: Float?) -> Float {
        guard let bed, bed > 0, let dialogue, dialogue > 0 else { return fallbackBedGain }

        let target = dialogue * powf(10, bedBelowDialogue / 20)
        return min(maximumBedGain, max(minimumBedGain, target / bed))
    }

    /// Measures a pack's dialogue and its bed under that dialogue, and places one under the
    /// other for the whole scene.
    static func bedGain(for bed: AVAudioPCMBuffer, in pack: DubPack) -> Float {
        bedGain(bed: bedLevel(of: bed, under: pack.lines), dialogue: dialogueLevel(of: pack))
    }
}
