//
//  DubVoiceLevelTests.swift
//  ReverseSingingTests
//
//  A take arrives at the level the film played the line at
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

@Suite("Voice Level")
struct DubVoiceLevelTests {

    /// A buffer of speech-ish tone at `amplitude`, with `leadingSilence` seconds of nothing
    /// in front of it.
    private func voice(
        amplitude: Float,
        seconds: Double = 1,
        leadingSilence: Double = 0
    ) throws -> AVAudioPCMBuffer {
        let sampleRate = DubAudioLoader.canonicalFormat.sampleRate
        let total = AVAudioFrameCount((seconds + leadingSilence) * sampleRate)
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: DubAudioLoader.canonicalFormat, frameCapacity: total)
        )
        buffer.frameLength = total

        let samples = try #require(buffer.floatChannelData)[0]
        let silent = Int(leadingSilence * sampleRate)

        for frame in 0..<Int(total) {
            guard frame >= silent else {
                samples[frame] = 0
                continue
            }
            samples[frame] = amplitude * sinf(2 * .pi * 220 * Float(frame) / Float(sampleRate))
        }
        return buffer
    }

    // MARK: - Measuring

    @Test func aLouderRecordingMeasuresLouder() throws {
        let quiet = try #require(DubVoiceLevel.speechLevel(of: try voice(amplitude: 0.1)))
        let loud = try #require(DubVoiceLevel.speechLevel(of: try voice(amplitude: 0.5)))

        #expect(loud > quiet)
        #expect(abs(loud / quiet - 5) < 0.1, "and by the amount it is actually louder by")
    }

    /// The reason the measurement skips the quiet parts: otherwise a nervous pause before the
    /// first word would read as a quiet take and be boosted to compensate for it.
    @Test func silenceBeforeTheLineDoesNotMakeTheTakeLookQuieter() throws {
        let straightIn = try #require(DubVoiceLevel.speechLevel(of: try voice(amplitude: 0.3)))
        let afterAPause = try #require(
            DubVoiceLevel.speechLevel(of: try voice(amplitude: 0.3, leadingSilence: 2))
        )

        #expect(abs(straightIn - afterAPause) < 0.01)
    }

    @Test func aSilentBufferHasNothingToMeasure() throws {
        #expect(DubVoiceLevel.speechLevel(of: try voice(amplitude: 0)) == nil)
        #expect(DubVoiceLevel.speechLevel(of: try voice(amplitude: 0.001)) == nil)
    }

    // MARK: - Gain

    @Test func aQuietTakeIsBroughtUpAndALoudOneDown() {
        #expect(DubVoiceLevel.matchingGain(take: 0.1, reference: 0.2) > 1)
        #expect(DubVoiceLevel.matchingGain(take: 0.4, reference: 0.2) < 1)
    }

    /// Most of the way, not all of it. Closing the gap exactly would hand the take the
    /// reference's dynamics, and a reference has almost none.
    @Test func theMatchStopsShortOfTheReference() {
        let gain = DubVoiceLevel.matchingGain(take: 0.1, reference: 0.2)

        #expect(gain < 2, "an exact match would double it")
        #expect(gain > 1.4, "and it still closes most of the gap")

        // The fraction is a fraction of the difference in decibels, which is the only scale
        // on which "most of the way" means anything.
        let closed = log2(gain) / log2(2 as Float)
        #expect(abs(closed - DubVoiceLevel.strength) < 0.01)
    }

    /// However far apart they start, a take never overshoots the level it was aiming at.
    @Test func theMatchNeverGoesPastTheReference() {
        for takeLevel in stride(from: Float(0.02), through: 0.9, by: 0.02) {
            let reference: Float = 0.25
            let gain = DubVoiceLevel.matchingGain(take: takeLevel, reference: reference)
            let matched = takeLevel * gain

            if takeLevel < reference {
                #expect(matched <= reference + 0.001, "\(takeLevel) overshot upwards")
            } else {
                #expect(matched >= reference - 0.001, "\(takeLevel) overshot downwards")
            }
        }
    }

    @Test func aTakeAlreadyAtTheRightLevelIsLeftAlone() {
        #expect(DubVoiceLevel.matchingGain(take: 0.25, reference: 0.25) == 1)
    }

    /// Everything above the noise floor comes up together, so there is a limit past which the
    /// line arrives at the right level wrapped in room tone.
    @Test func theMatchIsClampedBothWays() {
        #expect(DubVoiceLevel.matchingGain(take: 0.001, reference: 0.5) == DubVoiceLevel.maximumBoost)
        #expect(DubVoiceLevel.matchingGain(take: 0.9, reference: 0.001) == DubVoiceLevel.maximumCut)
    }

    // MARK: - Applying

    @Test func aQuietTakeIsBroughtMostOfTheWayUpToTheFilm() throws {
        let take = try voice(amplitude: 0.1)
        let reference = try voice(amplitude: 0.3)

        let before = try #require(DubVoiceLevel.speechLevel(of: take))
        DubVoiceLevel.match(take, to: reference)

        let after = try #require(DubVoiceLevel.speechLevel(of: take))
        let target = try #require(DubVoiceLevel.speechLevel(of: reference))

        #expect(after > before, "it came up")
        #expect(after < target, "but not all the way to the reference")
        #expect(after > before + (target - before) / 2, "and it closed most of the gap")
    }

    @Test func aLoudTakeIsPulledMostOfTheWayDownToTheFilm() throws {
        let take = try voice(amplitude: 0.6)
        let reference = try voice(amplitude: 0.2)

        let before = try #require(DubVoiceLevel.speechLevel(of: take))
        DubVoiceLevel.match(take, to: reference)

        let after = try #require(DubVoiceLevel.speechLevel(of: take))
        let target = try #require(DubVoiceLevel.speechLevel(of: reference))

        #expect(after < before)
        #expect(after > target, "it stops short rather than landing on the reference")
    }

    /// The point of stopping short: two takes performed at different volumes are still at
    /// different volumes afterwards, even when the film played both lines identically.
    @Test func aPerformanceKeepsItsOwnDynamicsAfterMatching() throws {
        let soft = try voice(amplitude: 0.12)
        let loud = try voice(amplitude: 0.48)

        // The same line, played by the film at the same level both times.
        DubVoiceLevel.match(soft, to: try voice(amplitude: 0.3))
        DubVoiceLevel.match(loud, to: try voice(amplitude: 0.3))

        let softLevel = try #require(DubVoiceLevel.speechLevel(of: soft))
        let loudLevel = try #require(DubVoiceLevel.speechLevel(of: loud))

        #expect(loudLevel > softLevel * 1.3,
                "the shouted line is still audibly louder than the whispered one")
    }

    /// A take that came out silent is still a take. Scaling it by a gain derived from nothing
    /// is how a failed recording becomes a burst of amplified room noise.
    @Test func aSilentTakeIsLeftExactlyAsItIs() throws {
        let take = try voice(amplitude: 0)
        let reference = try voice(amplitude: 0.3)

        #expect(DubVoiceLevel.match(take, to: reference) == 1)

        let samples = try #require(take.floatChannelData)[0]
        #expect(samples[Int(DubAudioLoader.canonicalFormat.sampleRate / 2)] == 0)
    }

    @Test func aTakeWithNoReferenceToMatchIsLeftAlone() throws {
        let take = try voice(amplitude: 0.4)
        let reference = try voice(amplitude: 0)

        #expect(DubVoiceLevel.match(take, to: reference) == 1)
    }
}
