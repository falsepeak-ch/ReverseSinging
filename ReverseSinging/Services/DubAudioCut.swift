//
//  DubAudioCut.swift
//  ReverseSinging
//
//  Cuts the scene-length mix down to the stretches an export plays
//

import AVFoundation

/// Turns the mix of a whole scene into the audio of a cut: the chosen stretches, back to
/// back, in output time, with a short fade either side of every join.
///
/// A session reel is several separate moments of a film played one after another, and the
/// ambience under each one is whatever it was at that point in the scene — a fire close by in
/// the first, a corridor in the second. Butted together at full level that lands as a click
/// or a step at every join, which is the one edit in the whole export the user did not ask
/// for.
///
/// **Done on samples, not with an `AVAudioMix`.** The export is a passthrough whenever it can
/// be, and a passthrough copies packets: it accepts an audio mix and ignores it without
/// saying so. Rendering the joins through an export session instead loses the encoder's
/// priming on the way back into the composition and lands the audio forty milliseconds late,
/// which is a lip-sync fault on every reel. So the cut is made here, by reading the mix and
/// writing the stretches out through the same `AVAudioFile` path the mix itself came from,
/// which the composition already places correctly.
nonisolated enum DubAudioCut {

    /// How long the audio takes to hand over at a join, each way.
    ///
    /// Sixty milliseconds: long enough that nothing snaps, short enough to sit inside the
    /// lead-in every reference chunk carries before its first word.
    static let joinFade: TimeInterval = 0.06

    /// The cut's audio: `mix` itself when the cut is the scene from the top, since there is
    /// nothing to join and the mix is already the right file; otherwise a new file beside it.
    static func cut(_ mix: URL, to segments: [DubExportSegment], in directory: URL) throws -> URL {
        guard let first = segments.first else { throw DubExportError.nothingRecorded }
        if segments.count == 1, first.start <= 0 { return mix }

        let output = directory.appendingPathComponent("cut.m4a")
        try cut(mix, to: segments, output: output)
        return output
    }

    /// Writes `segments` of `mix`, in order, to `output`, fading into and out of every join.
    static func cut(_ mix: URL, to segments: [DubExportSegment], output: URL) throws {
        let source = try AVAudioFile(forReading: mix)
        let format = source.processingFormat
        let sampleRate = format.sampleRate

        let destination = try AVAudioFile(
            forWriting: output,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderBitRateKey: 192_000
            ]
        )

        let fadeFrames = Int(joinFade * sampleRate)

        for (index, segment) in segments.enumerated() {
            let start = min(source.length, max(0, AVAudioFramePosition(segment.start * sampleRate)))
            let count = min(source.length - start, AVAudioFramePosition(segment.duration * sampleRate))
            guard count > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
                continue
            }

            source.framePosition = start
            try source.read(into: buffer, frameCount: AVAudioFrameCount(count))

            if index > 0 { fadeIn(buffer, over: fadeFrames) }
            if index < segments.count - 1 { fadeOut(buffer, over: fadeFrames) }

            try destination.write(from: buffer)
        }
    }

    private static func fadeIn(_ buffer: AVAudioPCMBuffer, over frames: Int) {
        guard let channels = buffer.floatChannelData else { return }
        let length = min(frames, Int(buffer.frameLength))
        guard length > 0 else { return }

        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<length {
                channels[channel][frame] *= Float(frame) / Float(length)
            }
        }
    }

    private static func fadeOut(_ buffer: AVAudioPCMBuffer, over frames: Int) {
        guard let channels = buffer.floatChannelData else { return }
        let total = Int(buffer.frameLength)
        let length = min(frames, total)
        guard length > 0 else { return }

        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<length {
                channels[channel][total - 1 - frame] *= Float(frame) / Float(length)
            }
        }
    }
}
