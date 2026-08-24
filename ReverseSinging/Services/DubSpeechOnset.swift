//
//  DubSpeechOnset.swift
//  ReverseSinging
//
//  Where the talking actually starts inside a clip
//

import AVFoundation

/// Finds the silence in front of a line.
///
/// A pack gives one number per line: the timestamp of the audio chunk. That chunk is a slice
/// of the scene, so it routinely opens with a beat of room tone before anyone speaks — across
/// a real 62-line pack, 35 lines carry more than 250 ms of it and the spread runs to nearly
/// two seconds. Placing a take at the chunk's timestamp therefore puts the performer's first
/// word up to two seconds ahead of the character's mouth, by a different amount on every line.
///
/// So the chunk timestamp is used to find the line, and this is used to line it up.
enum DubSpeechOnset {

    /// Window the level is measured over. Short enough to place a consonant, long enough not
    /// to trip on a single sample of noise.
    private static let windowDuration: TimeInterval = 0.02

    /// Relative to the clip's own peak, so a quietly mastered reference and a take shouted
    /// into a phone are judged the same way.
    private static let threshold: Float = 0.04

    /// Refuses to trim away more than this much of a clip.
    ///
    /// Set high on purpose. A short interjection inside a long chunk genuinely is mostly
    /// run-up, and an earlier, tighter limit threw those away — which is the very case where
    /// getting the entry right matters most. What this still catches is the pathological
    /// reading: a clip whose only sound is a blip against the very end, where the dialogue
    /// itself sat under the threshold.
    private static let maximumFraction: Double = 0.9

    /// Seconds of near-silence before the first sustained sound, or 0 when there is none to
    /// find — including a clip that is silent throughout.
    static func leadIn(of buffer: AVAudioPCMBuffer) -> TimeInterval {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = buffer.format.sampleRate

        var peak: Float = 0
        for channel in 0..<channelCount {
            let samples = channels[channel]
            for frame in 0..<frameCount { peak = max(peak, abs(samples[frame])) }
        }
        guard peak > 0 else { return 0 }

        let level = peak * threshold
        let window = max(1, Int(windowDuration * sampleRate))

        var start = 0
        while start + window <= frameCount {
            var sumOfSquares: Float = 0
            for channel in 0..<channelCount {
                let samples = channels[channel]
                for frame in start..<(start + window) {
                    sumOfSquares += samples[frame] * samples[frame]
                }
            }

            let rms = (sumOfSquares / Float(window * channelCount)).squareRoot()
            if rms > level {
                let lead = Double(start) / sampleRate
                let clipDuration = Double(frameCount) / sampleRate
                return lead > clipDuration * maximumFraction ? 0 : lead
            }

            start += window
        }

        return 0
    }
}
