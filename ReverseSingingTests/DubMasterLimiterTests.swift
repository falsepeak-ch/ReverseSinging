//
//  DubMasterLimiterTests.swift
//  ReverseSingingTests
//
//  The brickwall between the mix and the output
//

import Testing
import AVFoundation
@testable import ReverseSinging

@Suite("Dub Master Limiter")
struct DubMasterLimiterTests {

    private let format = DubAudioLoader.canonicalFormat

    private func tone(_ duration: TimeInterval, _ amplitude: Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frames) {
            samples[frame] = amplitude * sinf(2 * .pi * 440 * Float(frame) / Float(format.sampleRate))
        }
        return buffer
    }

    /// Renders `voices` summed together, optionally through the limiter, and returns the peak.
    ///
    /// `installLimiterFirst` reproduces the scene player's ordering, where the limiter goes in
    /// at init and the voice nodes are attached afterwards, per pack.
    private func peakOfMix(
        voices: [Float],
        limited: Bool,
        installLimiterFirst: Bool = false
    ) throws -> Float {
        let engine = AVAudioEngine()
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

        if limited && installLimiterFirst {
            #expect(DubMasterLimiter.install(in: engine) != nil)
        }

        let nodes = voices.map { _ -> AVAudioPlayerNode in
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            return node
        }

        if limited && !installLimiterFirst {
            #expect(DubMasterLimiter.install(in: engine) != nil)
        }

        try engine.enableManualRenderingMode(.offline, format: outputFormat, maximumFrameCount: 4096)
        try engine.start()

        for (node, amplitude) in zip(nodes, voices) {
            node.scheduleBuffer(tone(1.0, amplitude), at: nil, options: [])
            node.play()
        }

        let total = AVAudioFramePosition(1.0 * outputFormat.sampleRate)
        let render = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
        var peak: Float = 0

        while engine.manualRenderingSampleTime < total {
            let remaining = total - engine.manualRenderingSampleTime
            let frames = AVAudioFrameCount(min(AVAudioFramePosition(render.frameCapacity), remaining))
            guard try engine.renderOffline(frames, to: render) == .success else { continue }

            for frame in 0..<Int(render.frameLength) {
                peak = max(peak, abs(render.floatChannelData![0][frame]))
            }
        }

        engine.stop()
        engine.disableManualRenderingMode()
        return peak
    }

    /// Three voices at 0.6 sum to 1.8. Anything above full scale is what the encoder squares
    /// off, so this is the case the limiter exists for.
    @Test func holdsASummedMixBelowFullScale() throws {
        let unlimited = try peakOfMix(voices: [0.6, 0.6, 0.6], limited: false)
        let limited = try peakOfMix(voices: [0.6, 0.6, 0.6], limited: true)

        #expect(unlimited > 1.0, "expected the raw sum to overshoot, got \(unlimited)")
        #expect(limited <= 1.0, "expected the limiter to hold the ceiling, got \(limited)")
        #expect(limited > 0.5, "expected a mix, not silence, got \(limited)")
    }

    /// The scene player installs the limiter before it knows how many voices the pack needs.
    /// Nodes attached afterwards still have to reach the output through it.
    @Test func worksWhenInstalledBeforeTheVoiceNodesExist() throws {
        let limited = try peakOfMix(voices: [0.6, 0.6, 0.6], limited: true, installLimiterFirst: true)

        #expect(limited <= 1.0, "got \(limited)")
        #expect(limited > 0.5, "got \(limited)")
    }

    /// A mix already inside the ceiling must come out untouched — a limiter that leans on
    /// ordinary dialogue would be squashing every export to fix a case that rarely happens.
    @Test func leavesAQuietMixAlone() throws {
        let unlimited = try peakOfMix(voices: [0.3], limited: false)
        let limited = try peakOfMix(voices: [0.3], limited: true)

        #expect(abs(limited - unlimited) < 0.02, "\(limited) vs \(unlimited)")
    }
}
