//
//  DubAudioLoader.swift
//  ReverseSinging
//
//  Loads dub audio into a single canonical format
//

@preconcurrency import AVFoundation

/// A dub pack mixes formats freely: reference lines are 48 kHz mono, the backing track is
/// 44.1 kHz stereo, and the user's takes are 44.1 kHz mono. An `AVAudioPlayerNode` keeps the
/// one format it was connected with for every buffer it is handed, so everything that plays
/// through the voice node has to be converted up front.
nonisolated enum DubAudioLoader {

    /// The format every voice buffer is converted to before scheduling or mixing.
    static let canonicalFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    /// Length of the fade applied to each end of a line, to stop takes from clicking when
    /// they're dropped onto the timeline.
    static let fadeDuration: TimeInterval = 0.01

    enum LoaderError: LocalizedError {
        case bufferCreationFailed
        case conversionFailed(Error?)

        var errorDescription: String? {
            switch self {
            case .bufferCreationFailed: return "Failed to create audio buffer"
            case .conversionFailed(let error): return "Failed to convert audio: \(error?.localizedDescription ?? "unknown")"
            }
        }
    }

    /// Reads a file into a buffer in its own format.
    static func loadBuffer(from url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat

        guard file.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw LoaderError.bufferCreationFailed
        }

        try file.read(into: buffer)
        return buffer
    }

    /// Reads a file and converts it to `canonicalFormat`, optionally fading the edges.
    static func loadVoiceBuffer(from url: URL, applyFades: Bool = true) throws -> AVAudioPCMBuffer {
        let source = try loadBuffer(from: url)
        let converted = try convert(source, to: canonicalFormat)
        if applyFades { applyEdgeFades(to: converted) }
        return converted
    }

    /// Sample-rate / channel-count conversion via `AVAudioConverter`.
    static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        if buffer.format == format { return buffer }

        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            throw LoaderError.conversionFailed(nil)
        }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024

        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw LoaderError.bufferCreationFailed
        }

        var suppliedInput = false
        var conversionError: NSError?

        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .endOfStream
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, conversionError == nil else {
            throw LoaderError.conversionFailed(conversionError)
        }

        return output
    }

    /// Linear fade in and out over `fadeDuration`, in place.
    static func applyEdgeFades(to buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let fadeFrames = min(Int(fadeDuration * buffer.format.sampleRate), frameLength / 2)
        guard fadeFrames > 0 else { return }

        for channel in 0..<Int(buffer.format.channelCount) {
            let samples = channels[channel]

            for frame in 0..<fadeFrames {
                let gain = Float(frame) / Float(fadeFrames)
                samples[frame] *= gain
                samples[frameLength - 1 - frame] *= gain
            }
        }
    }

    /// Rewrites a file so it is exactly `duration` long — trimmed if it ran over, padded with
    /// silence if it was cut short.
    ///
    /// A take has to be the length of the line it replaces. The recorder is told to stop on
    /// the audio clock, which handles the overrun, but a performer who stops early still
    /// leaves a short file; padding it keeps every take on the same axis, so the waveform
    /// laid over the reference compares delivery rather than length, and the mix drops each
    /// take into a slot of known size.
    ///
    /// A no-op when the file is already the right length, which is the usual case.
    static func normalizeDuration(ofFileAt url: URL, to duration: TimeInterval) throws {
        guard duration > 0 else { return }

        let format: AVAudioFormat
        let settings: [String: Any]
        let buffer: AVAudioPCMBuffer

        do {
            let file = try AVAudioFile(forReading: url)
            format = file.processingFormat
            settings = file.fileFormat.settings

            let target = AVAudioFrameCount((duration * format.sampleRate).rounded())
            guard target > 0, file.length != Int64(target) else { return }

            guard let scratch = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: target) else {
                throw LoaderError.bufferCreationFailed
            }

            let readCount = AVAudioFrameCount(min(file.length, Int64(target)))
            if readCount > 0 {
                try file.read(into: scratch, frameCount: readCount)
            }

            // Fresh buffer memory is not documented as zeroed, and a pad of whatever was on
            // the heap would be noise on the end of every short take.
            if let channels = scratch.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    channels[channel].advanced(by: Int(readCount))
                        .update(repeating: 0, count: Int(target - readCount))
                }
            }

            scratch.frameLength = target
            buffer = scratch
        }

        // Written alongside and moved into place, so a failure mid-write leaves the original
        // take intact rather than a half-file the user cannot play.
        let temporaryURL = url.deletingPathExtension()
            .appendingPathExtension("normalizing")
            .appendingPathExtension(url.pathExtension)

        do {
            let output = try AVAudioFile(forWriting: temporaryURL, settings: settings)
            try output.write(from: buffer)
        }

        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
    }

    /// Returns the portion of `buffer` from `offset` seconds onwards, or nil when the offset
    /// is past the end. Used when playback starts partway through a line.
    static func trimming(_ buffer: AVAudioPCMBuffer, fromOffset offset: TimeInterval) -> AVAudioPCMBuffer? {
        guard offset > 0 else { return buffer }

        let startFrame = Int(offset * buffer.format.sampleRate)
        let remaining = Int(buffer.frameLength) - startFrame
        guard remaining > 0 else { return nil }

        guard let trimmed = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: AVAudioFrameCount(remaining)
        ), let source = buffer.floatChannelData, let destination = trimmed.floatChannelData else {
            return nil
        }

        for channel in 0..<Int(buffer.format.channelCount) {
            destination[channel].update(from: source[channel].advanced(by: startFrame), count: remaining)
        }

        trimmed.frameLength = AVAudioFrameCount(remaining)
        return trimmed
    }
}
