//
//  DubVoiceAlignment.swift
//  ReverseSinging
//
//  Where a take lands on the scene's timeline
//

import AVFoundation

/// Decides where a line's voice is dropped on the scene timeline.
///
/// The single answer to "when does this take play". `DubPlayer` uses it for the scene you
/// hear in the app and `DubMixer` uses it for the file you share, so the export is the
/// playback — not two implementations that happen to agree today.
///
/// ## Pack timing is authoritative
///
/// This pack format defines the line timestamp as sample zero of both the reference chunk and
/// its replacement take. The original DubStage renderer converts that timestamp directly to
/// a sample index and adds the complete take there. Moving a take to a level-detected onset is
/// not alignment: film score and effects make those edges unreliable, and trimming changes
/// the declared overlap. Capture-device latency belongs in a separate calibrated offset.
nonisolated enum DubVoiceAlignment {

    /// A take and its authoritative pack time, ready to schedule.
    struct Placement {
        /// The complete take. Its sample zero represents the pack timestamp.
        let buffer: AVAudioPCMBuffer
        /// Where `buffer` starts on the scene's timeline, in seconds.
        let startTime: TimeInterval

        func endTime(sampleRate: Double) -> TimeInterval {
            startTime + Double(buffer.frameLength) / sampleRate
        }
    }

    /// Places the user's complete take at the line's declared timeline timestamp.
    ///
    /// - Parameters:
    ///   - take: the take, already converted to `DubAudioLoader.canonicalFormat`.
    ///   - line: the line it replaces.
    ///   - referenceURL: retained for source compatibility; placement never re-derives the
    ///     pack's timing from waveform amplitude.
    static func place(
        take: AVAudioPCMBuffer,
        for line: DubLine,
        referenceURL _: URL? = nil
    ) -> Placement {
        Placement(buffer: take, startTime: line.startTime)
    }

    /// Where a line's *reference* audio sits: exactly where it was cut from.
    ///
    /// Shifting the original against itself would only move the scene out from under its own
    /// backing track, so `.original` playback places every chunk at its own timestamp.
    static func placeReference(_ buffer: AVAudioPCMBuffer, for line: DubLine) -> Placement {
        Placement(buffer: buffer, startTime: line.startTime)
    }
}
