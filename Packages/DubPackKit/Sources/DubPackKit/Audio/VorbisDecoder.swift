//
//  VorbisDecoder.swift
//  DubPackKit
//

import AVFoundation
import Foundation
import XiphCodecs

/// Reads an Ogg Vorbis file into PCM buffers, one page's worth at a time.
///
/// libvorbisfile does the demuxing and decoding; this only turns its `float**` into
/// `AVAudioPCMBuffer`s in the file's own sample rate and channel count, capped at stereo. A
/// pack never carries more than stereo, and anything wider would only be downmixed later.
struct VorbisDecoder {

    /// Sample frames asked of libvorbisfile per read.
    private static let framesPerRead = 4096

    let format: AVAudioFormat
    private var file: OggVorbis_File

    /// Opens `url` and reads its headers.
    init(url: URL) throws(AudioConversionFailure) {
        var file = OggVorbis_File()
        let status = url.path.withCString { ov_fopen($0, &file) }
        guard status == 0 else {
            switch status {
            case OV_ENOTVORBIS, OV_EVERSION: throw .notVorbis
            case OV_EBADHEADER: throw .corrupt(detail: "bad header")
            case OV_EREAD: throw .unreadableSource(detail: "read failed")
            default: throw .corrupt(detail: "ov_fopen \(status)")
            }
        }

        guard let info = ov_info(&file, -1)?.pointee, info.rate > 0, info.channels > 0,
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(info.rate),
                channels: AVAudioChannelCount(min(2, Int(info.channels))),
                interleaved: false
              ) else {
            ov_clear(&file)
            throw .corrupt(detail: "unusable stream info")
        }

        self.file = file
        self.format = format
    }

    /// The next stretch of audio, or nil at the end of the stream. Damaged pages are skipped:
    /// a hole in the recording plays as a hole rather than costing the whole line.
    mutating func next() throws(AudioConversionFailure) -> AVAudioPCMBuffer? {
        var pcm: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>?
        var bitstream: Int32 = 0

        while true {
            let read = ov_read_float(&file, &pcm, Int32(Self.framesPerRead), &bitstream)
            if read == 0 { return nil }
            if read == OV_HOLE || read == OV_EBADLINK { continue }
            guard read > 0 else { throw .corrupt(detail: "ov_read_float \(read)") }

            let frames = AVAudioFrameCount(read)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
                  let destination = buffer.floatChannelData, let source = pcm else {
                throw .corrupt(detail: "no buffer")
            }
            buffer.frameLength = frames
            for channel in 0..<Int(format.channelCount) {
                guard let samples = source[channel] else { continue }
                destination[channel].update(from: samples, count: Int(frames))
            }
            return buffer
        }
    }

    mutating func close() {
        ov_clear(&file)
    }
}
