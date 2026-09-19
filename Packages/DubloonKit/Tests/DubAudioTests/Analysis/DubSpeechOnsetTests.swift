//
//  DubSpeechOnsetTests.swift
//  DubAudioTests
//
//  Finding where the talking starts inside a clip
//

import Testing
import AVFoundation
import DubAudio

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

    // MARK: - Windows

    private func clip(silence: TimeInterval, tone: TimeInterval, trailing: TimeInterval) -> AVAudioPCMBuffer {
        let format = DubAudioLoader.canonicalFormat
        let total = silence + tone + trailing
        let frames = AVAudioFrameCount(total * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        let start = Int(silence * format.sampleRate)
        let end = start + Int(tone * format.sampleRate)

        for frame in 0..<Int(frames) {
            samples[frame] = (frame >= start && frame < end)
                ? 0.6 * sinf(2 * .pi * 440 * Float(frame) / Float(format.sampleRate))
                : 0
        }
        return buffer
    }

    @Test func aWindowFindsBothEdgesOfTheSpeech() throws {
        let window = try #require(DubSpeechOnset.window(of: clip(silence: 0.5, tone: 1.2, trailing: 0.8)))

        #expect(abs(window.start - 0.5) < 0.05, "start was \(window.start)")
        #expect(abs(window.end - 1.7) < 0.05, "end was \(window.end)")
    }

    @Test func aWindowNeverClosesBeforeItOpens() throws {
        let window = try #require(DubSpeechOnset.window(of: clip(silence: 1.0, tone: 0.05, trailing: 1.0)))
        #expect(window.end >= window.start)
        #expect(window.duration >= 0)
    }

    @Test func silenceHasNoWindow() {
        #expect(DubSpeechOnset.window(of: clip(silence: 2, tone: 0, trailing: 0)) == nil)
    }

    /// `leadIn` remains a useful description of the clip for captions and scoring.
    @Test func leadInStillAgreesWithTheWindowStart() throws {
        let buffer = clip(silence: 0.75, tone: 1.0, trailing: 0.5)
        let window = try #require(DubSpeechOnset.window(of: buffer))

        #expect(abs(DubSpeechOnset.leadIn(of: buffer) - window.start) < 0.001)
    }
}
