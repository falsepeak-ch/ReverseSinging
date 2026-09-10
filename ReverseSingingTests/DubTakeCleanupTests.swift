//
//  DubTakeCleanupTests.swift
//  ReverseSingingTests
//
//  The room goes down between the words, and the words survive it
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

@Suite("Take Cleanup")
struct DubTakeCleanupTests {

    private let sampleRate: Double = 44_100

    /// A take: constant room tone throughout, with a spoken stretch in the middle of it.
    private func take(
        room: Float,
        speech: Float,
        speechFrom: Double = 1,
        speechTo: Double = 2,
        seconds: Double = 3
    ) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(seconds * sampleRate))
        )
        buffer.frameLength = buffer.frameCapacity

        let samples = try #require(buffer.floatChannelData)[0]
        var seed: UInt64 = 42

        for frame in 0..<Int(buffer.frameLength) {
            // A cheap deterministic noise, so the test is the same every run.
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let noise = (Float(seed >> 40) / Float(1 << 24) - 0.5) * 2 * room

            let time = Double(frame) / sampleRate
            let voiced = time >= speechFrom && time < speechTo
            let tone = voiced ? speech * sinf(2 * .pi * 200 * Float(frame) / Float(sampleRate)) : 0

            samples[frame] = noise + tone
        }
        return buffer
    }

    private func rms(_ buffer: AVAudioPCMBuffer, from: Double, to: Double) throws -> Float {
        let samples = try #require(buffer.floatChannelData)[0]
        let first = Int(from * sampleRate)
        let last = min(Int(buffer.frameLength), Int(to * sampleRate))
        var sum: Double = 0
        for frame in first..<last {
            sum += Double(samples[frame]) * Double(samples[frame])
        }
        return Float((sum / Double(last - first)).squareRoot())
    }

    private func decibels(_ value: Float) -> Float { 20 * log10f(max(value, 1e-9)) }

    // MARK: - The point of it

    @Test func theRoomIsPushedDownBetweenTheWords() throws {
        let buffer = try take(room: 0.02, speech: 0.3)

        let roomBefore = try rms(buffer, from: 0.1, to: 0.8)
        #expect(DubTakeCleanup.apply(to: buffer))
        let roomAfter = try rms(buffer, from: 0.1, to: 0.8)

        let reduction = decibels(roomBefore) - decibels(roomAfter)
        #expect(reduction > 10, "the room came down by \(reduction) dB, which is not enough")
    }

    @Test func theSpeechIsLeftWhereItWas() throws {
        let buffer = try take(room: 0.02, speech: 0.3)

        let speechBefore = try rms(buffer, from: 1.3, to: 1.7)
        DubTakeCleanup.apply(to: buffer)
        let speechAfter = try rms(buffer, from: 1.3, to: 1.7)

        #expect(abs(decibels(speechBefore) - decibels(speechAfter)) < 0.5)
    }

    /// The reason this exists: two takes with rooms ten decibels apart stop being ten
    /// decibels apart, so the scene does not step at the line boundary between them. Each is
    /// aimed at the same distance below its own voice, which is what closes the gap.
    @Test func twoTakesWithVeryDifferentRoomsEndUpCloseTogether() throws {
        let quietRoom = try take(room: 0.006, speech: 0.3)
        let loudRoom = try take(room: 0.02, speech: 0.3)

        let before = decibels(try rms(loudRoom, from: 0.1, to: 0.8))
            - decibels(try rms(quietRoom, from: 0.1, to: 0.8))
        #expect(before > 8, "they really do start far apart")

        DubTakeCleanup.apply(to: quietRoom)
        DubTakeCleanup.apply(to: loudRoom)

        let after = decibels(try rms(loudRoom, from: 0.1, to: 0.8))
            - decibels(try rms(quietRoom, from: 0.1, to: 0.8))
        #expect(after < before / 2, "and they are much closer afterwards")
    }

    // MARK: - Not breaking the performance

    /// An expander that opens a window late clips the front off every consonant.
    @Test func theFirstMomentOfAWordIsNotSwallowed() throws {
        let buffer = try take(room: 0.01, speech: 0.3, speechFrom: 1, speechTo: 2)

        let onsetBefore = try rms(buffer, from: 1.0, to: 1.02)
        DubTakeCleanup.apply(to: buffer)
        let onsetAfter = try rms(buffer, from: 1.0, to: 1.02)

        #expect(decibels(onsetBefore) - decibels(onsetAfter) < 3,
                "the very start of the word survived")
    }

    /// And one that closes fast cuts the tail off, which is heard as a word being clipped.
    @Test func theTailOfAWordIsNotCutOff() throws {
        // A room that actually needs bringing down: 23 dB under the speech, not 40.
        let levels = [Float](repeating: 0.3, count: 20) + [Float](repeating: 0.02, count: 40)
        let gains = DubTakeCleanup.gains(for: levels)

        // A window after the speech stops, the expander should still be most of the way open.
        #expect(gains[21] > 0.7, "it closes gradually rather than at once")
        #expect(gains.last! < 0.3, "and it does eventually get there")
        #expect(gains[19] > 0.95, "and it was fully open through the word itself")
    }

    // MARK: - Leaving well alone

    /// A recording where the room is nearly as loud as the voice cannot be separated, and an
    /// expander made to try takes lumps out of the words.
    @Test func aTakeWithNoUsableSeparationIsLeftAlone() {
        let levels = [Float](repeating: 0.1, count: 30) + [Float](repeating: 0.13, count: 30)
        let gains = DubTakeCleanup.gains(for: levels)

        #expect(gains.allSatisfy { $0 == 1 })
    }

    @Test func aBufferTooShortToMeasureIsLeftAlone() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128))
        buffer.frameLength = buffer.frameCapacity

        let samples = try #require(buffer.floatChannelData)[0]
        for frame in 0..<Int(buffer.frameLength) { samples[frame] = 0.4 }

        #expect(!DubTakeCleanup.apply(to: buffer))
        #expect(samples[64] == 0.4)
    }

    @Test func theCurveStaysWithinItsBounds() {
        let levels = (0..<200).map { Float($0 % 17) / 17 }
        let gains = DubTakeCleanup.gains(for: levels)

        #expect(gains.allSatisfy { $0 >= DubTakeCleanup.depth - 0.001 && $0 <= 1.001 })
    }
}
