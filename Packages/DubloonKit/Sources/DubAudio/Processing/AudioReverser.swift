//
//  AudioReverser.swift
//  DubAudio
//
//  A recording played backwards, for the reverse-singing game
//

public import AVFoundation

/// Writes a recording out backwards, sample for sample, in the format it was read in.
public enum AudioReverser {

    /// Reads `input`, reverses every channel, and writes the result to `output`.
    ///
    /// Blocking: call it off the main actor. The output keeps the input's sample rate, channel
    /// count and processing format.
    public static func reverseFile(at input: URL, to output: URL) throws {
        let buffer = try DubAudioLoader.loadBuffer(from: input)
        reverse(buffer)

        let format = buffer.format
        let file = try AVAudioFile(
            forWriting: output,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        try file.write(from: buffer)
    }

    /// Reverses every channel of `buffer` in place.
    public static func reverse(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }

        let frames = Int(buffer.frameLength)
        for channel in 0..<Int(buffer.format.channelCount) {
            var samples = UnsafeMutableBufferPointer(start: channels[channel], count: frames)
            samples.reverse()
        }
    }
}
