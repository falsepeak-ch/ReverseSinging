//
//  DubSpeechOnsetTests.swift
//  ReverseSingingTests
//
//  Finding where the talking starts inside a clip
//

import Testing
import AVFoundation
@testable import ReverseSinging

@Suite("Dub Speech Onset")
struct DubSpeechOnsetTests {

    private func clip(silence: TimeInterval, thenTone tone: TimeInterval, amplitude: Float = 0.6) -> AVAudioPCMBuffer {
        let format = DubAudioLoader.canonicalFormat
        let frames = AVAudioFrameCount((silence + tone) * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        let silent = Int(silence * format.sampleRate)
        for frame in 0..<Int(frames) {
            samples[frame] = frame < silent
                ? 0
                : amplitude * sinf(2 * .pi * 440 * Float(frame - silent) / Float(format.sampleRate))
        }
        return buffer
    }

    @Test func findsTheRunUp() {
        let lead = DubSpeechOnset.leadIn(of: clip(silence: 0.5, thenTone: 2.0))
        #expect(abs(lead - 0.5) < 0.03, "got \(lead)")
    }

    @Test func reportsNothingForAClipThatOpensOnSpeech() {
        #expect(DubSpeechOnset.leadIn(of: clip(silence: 0, thenTone: 2.0)) == 0)
    }

    @Test func reportsNothingForSilence() {
        #expect(DubSpeechOnset.leadIn(of: clip(silence: 2.0, thenTone: 0)) == 0)
    }

    /// A short interjection inside a long chunk is a real shape, not a misreading: the run-up
    /// can genuinely be most of the clip.
    @Test func handlesARunUpLongerThanTheSpeech() {
        let lead = DubSpeechOnset.leadIn(of: clip(silence: 2.0, thenTone: 0.6))
        #expect(abs(lead - 2.0) < 0.03, "got \(lead)")
    }

    /// Judged against the clip's own peak, so a quietly mastered reference reads the same as
    /// a take shouted into a phone.
    @Test func isIndependentOfHowLoudTheClipIs() {
        let quiet = DubSpeechOnset.leadIn(of: clip(silence: 0.8, thenTone: 1.5, amplitude: 0.05))
        let loud = DubSpeechOnset.leadIn(of: clip(silence: 0.8, thenTone: 1.5, amplitude: 0.95))

        #expect(abs(quiet - loud) < 0.03, "\(quiet) vs \(loud)")
    }
}
