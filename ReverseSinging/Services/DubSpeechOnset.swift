//
//  DubSpeechOnset.swift
//  ReverseSinging
//
//  Where the talking actually starts and stops inside a clip
//

import AVFoundation

/// Finds the silence wrapped around a line.
///
/// A pack gives the authoritative chunk timestamp. This detector describes where sustained
/// sound appears inside that chunk so captions and timing scores can use a tighter window.
/// It deliberately does not place, trim or stretch audio: score and effects are not reliable
/// edit markers, and changing a line's declared interval destroys intentional overlaps.
nonisolated enum DubSpeechOnset {

    /// The stretch of a clip that is actually speech, in seconds from the clip's own start.
    struct Window: Equatable {
        let start: TimeInterval
        let end: TimeInterval

        var duration: TimeInterval { max(0, end - start) }
    }

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
        guard let window = window(of: buffer) else { return 0 }

        let clipDuration = Double(buffer.frameLength) / buffer.format.sampleRate
        return window.start > clipDuration * maximumFraction ? 0 : window.start
    }

    /// First and last sustained sound in the clip, or nil when nothing rises above the floor.
    ///
    /// Both edges come from one pass over the same level envelope, so the window can never
    /// close before it opens.
    static func window(of buffer: AVAudioPCMBuffer) -> Window? {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return nil }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = buffer.format.sampleRate

        var peak: Float = 0
        for channel in 0..<channelCount {
            let samples = channels[channel]
            for frame in 0..<frameCount { peak = max(peak, abs(samples[frame])) }
        }
        guard peak > 0 else { return nil }

        let level = peak * threshold
        let window = max(1, Int(windowDuration * sampleRate))

        var firstLoud: Int?
        var lastLoud: Int?
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
                if firstLoud == nil { firstLoud = start }
                lastLoud = start + window
            }

            start += window
        }

        guard let firstLoud, let lastLoud else { return nil }

        return Window(
            start: Double(firstLoud) / sampleRate,
            end: min(Double(lastLoud) / sampleRate, Double(frameCount) / sampleRate)
        )
    }
}
