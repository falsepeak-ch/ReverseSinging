//
//  ImitationReelAudio.swift
//  ReverseSinging
//
//  The soundtrack of an imitation video, laid out in PCM
//

import AVFoundation
import DubAudio

/// Builds the video's soundtrack: silence under the intro, the original, the attempt, and a
/// thud when the stamp lands.
///
/// Laid out sample by sample and written once as AAC, then inserted whole at time zero. Not
/// assembled from clips in a composition: an `audioMix` is ignored by a passthrough export,
/// and audio re-encoded through an export preset lands about 40 ms late. Both were learned
/// the hard way on the dub export.
nonisolated enum ImitationReelAudio {

    /// The attempt is brought up to this peak, dBFS. Phone takes arrive anywhere from a
    /// whisper to a clipped shout; the original is already normalised.
    private static let takePeak: Float = -3
    /// Never amplify a take by more than this, dB. A near-silent take stays near-silent
    /// rather than becoming a wall of room noise.
    private static let maximumTakeGain: Float = 18

    static func render(
        referenceURL: URL,
        takeURL: URL,
        timeline: ImitationReelTimeline,
        celebrates: Bool,
        to destination: URL
    ) throws {
        let format = DubAudioLoader.canonicalFormat
        let rate = format.sampleRate
        let totalFrames = AVAudioFrameCount((timeline.total * rate).rounded(.up))

        guard let mix = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            throw ImitationReelError.setupFailed
        }
        mix.frameLength = totalFrames
        let output = mix.floatChannelData![0]
        output.update(repeating: 0, count: Int(totalFrames))

        func lay(_ buffer: AVAudioPCMBuffer, at time: TimeInterval, gain: Float = 1) {
            guard let samples = buffer.floatChannelData?[0] else { return }
            let start = Int((time * rate).rounded())
            let count = min(Int(buffer.frameLength), Int(totalFrames) - start)
            guard start >= 0, count > 0 else { return }
            for index in 0..<count { output[start + index] += samples[index] * gain }
        }

        let reference = try DubAudioLoader.loadVoiceBuffer(from: referenceURL, applyFades: false)
        lay(reference, at: timeline.referenceStart)

        let take = try DubAudioLoader.loadVoiceBuffer(from: takeURL, applyFades: true)
        lay(take, at: timeline.takeStart, gain: gain(toPeak: takePeak, of: take))

        let stamp: UISound = celebrates ? .clapperSnap : .errorThunk
        if let sting = sound(stamp) { lay(sting, at: timeline.stampTime, gain: 0.8) }
        if celebrates, let chime = sound(.projectorChime) {
            lay(chime, at: timeline.stampTime + 0.08, gain: 0.5)
        }

        // Laying clips over each other can only push past full scale at the stamp; clamp
        // rather than limit, it is one transient.
        for index in 0..<Int(totalFrames) { output[index] = max(-1, min(1, output[index])) }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        let file = try AVAudioFile(forWriting: destination, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ])
        try file.write(from: mix)
    }

    private static func gain(toPeak target: Float, of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 1 }
        var peak: Float = 0
        for index in 0..<Int(buffer.frameLength) { peak = max(peak, abs(samples[index])) }
        guard peak > 0 else { return 1 }
        let needed = target - 20 * log10(peak)
        return pow(10, min(needed, maximumTakeGain) / 20)
    }

    private static func sound(_ sound: UISound) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { return nil }
        return try? DubAudioLoader.loadVoiceBuffer(from: url, applyFades: false)
    }
}
