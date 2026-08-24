//
//  DubVoiceAlignment.swift
//  ReverseSinging
//
//  Where a take lands on the scene's timeline
//

import AVFoundation

/// Decides where a line's voice is dropped on the scene timeline, and trims it to fit.
///
/// The single answer to "when does this take play". `DubPlayer` uses it for the scene you
/// hear in the app and `DubMixer` uses it for the file you share, so the export is the
/// playback — not two implementations that happen to agree today.
///
/// ## Why a take is not simply placed at the line's timestamp
///
/// A pack gives one number per line: the timestamp of the audio *chunk* it was cut from. That
/// chunk opens with a beat of room tone before anyone speaks, by a different amount on every
/// line. The performer, meanwhile, starts their take on the countdown and takes their own
/// moment to come in.
///
/// Placing raw take at raw timestamp therefore stacks two independent errors and the voice
/// lands anywhere from a hair to two seconds off the character's mouth. Instead both run-ups
/// are measured away and the take's first word is put exactly where the original's first word
/// is: onset to onset. What the performer hears is their own delivery, on the beat.
nonisolated enum DubVoiceAlignment {

    /// A take, trimmed and timed, ready to schedule.
    struct Placement {
        /// The take with its run-up removed. Fades re-applied, so the cut cannot click.
        let buffer: AVAudioPCMBuffer
        /// Where `buffer` starts on the scene's timeline, in seconds.
        let startTime: TimeInterval

        func endTime(sampleRate: Double) -> TimeInterval {
            startTime + Double(buffer.frameLength) / sampleRate
        }
    }

    /// Aligns the user's take for `line` onto the scene timeline.
    ///
    /// - Parameters:
    ///   - take: the take, already converted to `DubAudioLoader.canonicalFormat`.
    ///   - line: the line it replaces. Its stored speech window is what the take is aligned to.
    ///   - referenceURL: a last resort, read **only** when the line carries no measured window.
    ///     Packs are measured at import and re-measured by `DubPackLibrary` when a manifest
    ///     predates the field, so in practice this never opens a file. It exists because the
    ///     alternative failure is silent and severe: an unmeasured line would place every take
    ///     at the chunk's start, up to two seconds before the character speaks — precisely the
    ///     bug the speech window was introduced to fix.
    static func place(
        take: AVAudioPCMBuffer,
        for line: DubLine,
        referenceURL: URL? = nil
    ) -> Placement {
        let startTime = line.startTime + speechLead(for: line, referenceURL: referenceURL)
        let takeLead = DubSpeechOnset.leadIn(of: take)

        guard takeLead > 0, let trimmed = DubAudioLoader.trimming(take, fromOffset: takeLead) else {
            // Nothing to trim: the buffer still carries the fades the loader applied.
            return Placement(buffer: take, startTime: startTime)
        }

        // The trim cut the loader's fade-in off the front, leaving a hard edge mid-signal.
        // Fading the copy restores it; the tail simply gets faded twice over 10 ms, which is
        // inaudible and far cheaper than threading a "don't fade yet" flag through the loader.
        DubAudioLoader.applyEdgeFades(to: trimmed)

        return Placement(buffer: trimmed, startTime: startTime)
    }

    /// Where the original's first word sits inside its chunk.
    ///
    /// The stored window always wins. Measuring is the fallback for a line that has none, and
    /// zero is the fallback for a reference that cannot be read — the behaviour that shipped
    /// before windows existed.
    private static func speechLead(for line: DubLine, referenceURL: URL?) -> TimeInterval {
        if line.speech != nil { return line.speechLead }

        guard let referenceURL,
              let reference = try? DubAudioLoader.loadVoiceBuffer(from: referenceURL, applyFades: false)
        else { return line.speechLead }

        return min(DubSpeechOnset.leadIn(of: reference), line.duration)
    }

    /// Where a line's *reference* audio sits: exactly where it was cut from.
    ///
    /// Shifting the original against itself would only move the scene out from under its own
    /// backing track, so `.original` playback places every chunk at its own timestamp.
    static func placeReference(_ buffer: AVAudioPCMBuffer, for line: DubLine) -> Placement {
        Placement(buffer: buffer, startTime: line.startTime)
    }
}
