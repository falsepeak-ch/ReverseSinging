//
//  ImitationScorerTests.swift
//  DubScoringTests
//
//  An impression is judged on its shape, not on the voice doing it
//

import Testing
import AVFoundation
import DubAudio
@testable import DubScoring

@Suite("Imitation Scoring")
struct ImitationScorerTests {

    private let sampleRate = DubAudioLoader.canonicalFormat.sampleRate

    // MARK: - Fixtures

    /// A tone whose pitch follows `hz(t)` for `duration` seconds, with a little silence either
    /// side, the way a real recording has.
    private func sweep(
        duration: TimeInterval,
        padding: TimeInterval = 0.2,
        amplitude: Float = 0.5,
        hz: (Double) -> Double
    ) -> AVAudioPCMBuffer {
        let total = duration + padding * 2
        let format = DubAudioLoader.canonicalFormat
        let frames = AVAudioFrameCount(total * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        var phase = 0.0
        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate - padding
            guard t >= 0, t < duration else { samples[frame] = 0; continue }
            phase += 2 * .pi * hz(t) / sampleRate
            samples[frame] = amplitude * Float(sin(phase))
        }
        return buffer
    }

    /// White noise for `duration` seconds, a stand-in for a hiss or a sneeze.
    private func noise(duration: TimeInterval, padding: TimeInterval = 0.2) -> AVAudioPCMBuffer {
        let format = DubAudioLoader.canonicalFormat
        let frames = AVAudioFrameCount((duration + padding * 2) * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        var generator = SystemRandomNumberGenerator()
        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate - padding
            samples[frame] = (t >= 0 && t < duration) ? Float.random(in: -0.4...0.4, using: &generator) : 0
        }
        return buffer
    }

    private func silence(duration: TimeInterval) -> AVAudioPCMBuffer {
        let format = DubAudioLoader.canonicalFormat
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for frame in 0..<Int(frames) { buffer.floatChannelData![0][frame] = 0 }
        return buffer
    }

    /// A siren-ish wail: up an octave and back down.
    private func wail(from base: Double, duration: TimeInterval) -> AVAudioPCMBuffer {
        sweep(duration: duration) { t in base * pow(2, sin(.pi * t / duration)) }
    }

    // MARK: - Tests

    @Test("A sound scores near the top against itself")
    func identicalScoresHigh() throws {
        let sound = wail(from: 300, duration: 1.2)
        let score = try #require(ImitationScorer.score(take: sound, reference: sound))
        #expect(score.overall > 90)
        #expect(score.grade == .perfect)
    }

    @Test("The same shape in a different register still scores high")
    func transposedScoresHigh() throws {
        let reference = wail(from: 400, duration: 1.2)
        let take = wail(from: 400 / pow(2, 7.0 / 12), duration: 1.2)
        let score = try #require(ImitationScorer.score(take: take, reference: reference))
        #expect(try #require(score.pitch) > 80)
        #expect(score.overall > 75)
    }

    @Test("A rising sweep is a poor impression of a falling one")
    func oppositeDirectionScoresLow() throws {
        let falling = sweep(duration: 1) { t in 800 * pow(2, -2 * t) }
        let rising = sweep(duration: 1) { t in 200 * pow(2, 2 * t) }
        let right = try #require(ImitationScorer.score(take: falling, reference: falling))
        let wrong = try #require(ImitationScorer.score(take: rising, reference: falling))
        #expect(try #require(wrong.pitch) < 40)
        #expect(wrong.overall < right.overall - 25)
    }

    @Test("Performing a little slower is forgiven")
    func slowerScoresHigh() throws {
        let reference = wail(from: 300, duration: 1.0)
        let take = wail(from: 300, duration: 1.2)
        let score = try #require(ImitationScorer.score(take: take, reference: reference))
        #expect(score.overall > 80)
    }

    @Test("Much too short loses the duration marks")
    func tooShortLosesDuration() throws {
        let reference = wail(from: 300, duration: 2.0)
        let take = wail(from: 300, duration: 0.5)
        let score = try #require(ImitationScorer.score(take: take, reference: reference))
        #expect(score.duration < 10)
    }

    @Test("A hum is a poor impression of a hiss")
    func toneVersusNoise() throws {
        let hiss = noise(duration: 1)
        let hum = sweep(duration: 1) { _ in 180 }
        let score = try #require(ImitationScorer.score(take: hum, reference: hiss))
        let fair = try #require(ImitationScorer.score(take: noise(duration: 1), reference: hiss))
        #expect(score.pitch == nil)
        #expect(score.tone < 50)
        #expect(fair.tone > score.tone + 30)
    }

    @Test("Silence scores zero, and an empty reference can't be scored")
    func silence() {
        let reference = wail(from: 300, duration: 1)
        #expect(ImitationScorer.score(take: silence(duration: 1), reference: reference) == .silent)
        #expect(ImitationScorer.score(take: reference, reference: silence(duration: 1)) == nil)
    }

    @Test("Warping finds a stretched copy of the same contour")
    func warping() {
        let a: [Float] = [0, 1, 2, 3, 2, 1, 0]
        let stretched: [Float] = [0, 0, 1, 1, 2, 2, 3, 3, 2, 2, 1, 1, 0, 0]
        #expect(DynamicTimeWarping.averageCost(a, stretched) < 0.01)
        #expect(DynamicTimeWarping.averageCost(a, a.reversed().map { 3 - $0 }) > 0.5)
    }
}
