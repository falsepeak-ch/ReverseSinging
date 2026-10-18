//
//  HomeVideoMixer.swift
//  ReverseSinging
//
//  Lays a recorded voice over a video from the user's own library
//

@preconcurrency import AVFoundation
import DubAudio
import Foundation

/// The Home Video Dub export: the user's clip, picture untouched, with their voice as the sound.
///
/// Built the way the dub export learned to be built (see `DubMixer`): the soundtrack is mixed in
/// the PCM domain and written with `AVAudioFile`, which lands sample-accurate, and the picture
/// is remuxed with the passthrough preset, which never re-encodes a frame. An `AVAudioMix` would
/// be ignored by passthrough without a word, so there isn't one.
nonisolated enum HomeVideoMixer {

    /// Longer clips are cut to their first minute: long enough for any joke, short enough that
    /// the whole thing is one take and the file stays shareable.
    static let maximumDuration: TimeInterval = 60

    /// The original soundtrack, when kept, sits about 10 dB under the voice. One static gain,
    /// never a ducker that pumps between words.
    static let originalGain: Float = 0.32

    /// Where the voice's speech is brought to: about −20 dBFS RMS, a normal dialogue level.
    private static let voiceTarget: Float = 0.1

    /// Summed peaks are pulled under this with one gain across the whole file.
    private static let peakCeiling: Float = 0.89

    private static let sampleRate: Double = 44_100

    enum MixError: LocalizedError {
        case noPicture
        case tooShort
        case bufferFailed
        case readFailed((any Error)?)
        case exportFailed((any Error)?)

        var errorDescription: String? {
            switch self {
            case .noPicture: return "The file has no video track"
            case .tooShort: return "The video is too short"
            case .bufferFailed: return "Could not allocate an audio buffer"
            case .readFailed(let error): return "Could not read the video's sound: \(error?.localizedDescription ?? "unknown")"
            case .exportFailed(let error): return "Could not write the video: \(error?.localizedDescription ?? "unknown")"
            }
        }
    }

    /// A picked video, measured once.
    struct Source: Equatable, Sendable {
        let url: URL
        /// The part that is used, capped at `maximumDuration`.
        let duration: TimeInterval
        /// The clip was longer than the cap and only its start is used.
        let wasTrimmed: Bool
        let hasSound: Bool
    }

    // MARK: - Files

    /// Picked clips and takes. Caches, not Documents: none of it is worth backing up, and the
    /// finished video goes out through the share sheet.
    static var workingDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("HomeVideo", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var voiceURL: URL { workingDirectory.appendingPathComponent("voice.caf") }
    static var soundtrackURL: URL { workingDirectory.appendingPathComponent("soundtrack.m4a") }
    /// The clip's own sound, decoded once when it is picked, for drawing its waveform.
    static var originalSoundURL: URL { workingDirectory.appendingPathComponent("original.caf") }

    /// Clears out earlier clips and takes, so a library of big videos doesn't pile up in Caches.
    static func removeWorkingFiles(except keep: URL? = nil) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: workingDirectory, includingPropertiesForKeys: nil
        )) ?? []
        for file in files where file.standardizedFileURL != keep?.standardizedFileURL {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Inspecting

    @concurrent
    static func inspect(_ url: URL) async throws -> Source {
        let asset = AVURLAsset(url: url)
        guard try await !asset.loadTracks(withMediaType: .video).isEmpty else { throw MixError.noPicture }
        let full = try await asset.load(.duration).seconds
        guard full.isFinite, full >= 0.5 else { throw MixError.tooShort }
        let hasSound = try await !asset.loadTracks(withMediaType: .audio).isEmpty
        return Source(
            url: url,
            duration: min(full, maximumDuration),
            wasTrimmed: full > maximumDuration + 0.05,
            hasSound: hasSound
        )
    }

    // MARK: - Rendering

    /// Writes the finished video.
    /// - Parameters:
    ///   - voice: the take, whose sample zero is the video's first frame.
    ///   - keepOriginal: whether the clip's own sound plays quietly under the voice.
    @concurrent
    static func render(
        source: Source,
        voice: URL,
        keepOriginal: Bool,
        to outputURL: URL
    ) async throws -> URL {
        let frames = AVAudioFrameCount(source.duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let mix = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let out = mix.floatChannelData?[0] else { throw MixError.bufferFailed }
        mix.frameLength = frames
        out.update(repeating: 0, count: Int(frames))

        if keepOriginal, source.hasSound {
            try await addOriginal(of: source, into: out, frames: Int(frames), gain: originalGain)
        }

        let take = try levelledVoice(from: voice)
        if let samples = take.floatChannelData?[0] {
            for index in 0..<min(Int(take.frameLength), Int(frames)) {
                out[index] += samples[index]
            }
        }

        var peak: Float = 0
        for index in 0..<Int(frames) { peak = max(peak, abs(out[index])) }
        if peak > peakCeiling {
            let gain = peakCeiling / peak
            for index in 0..<Int(frames) { out[index] *= gain }
        }

        try writeSoundtrack(mix, to: soundtrackURL)
        return try await remux(source: source, soundtrack: soundtrackURL, to: outputURL)
    }

    /// Writes the clip's own sound, at full level and on the picture's clock, to
    /// `originalSoundURL`, so the studio can draw it under the picture. Nil for a silent clip.
    @concurrent
    static func extractOriginalSound(of source: Source) async throws -> URL? {
        guard source.hasSound else { return nil }
        let frames = AVAudioFrameCount(source.duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let out = buffer.floatChannelData?[0] else { throw MixError.bufferFailed }
        buffer.frameLength = frames
        out.update(repeating: 0, count: Int(frames))
        try await addOriginal(of: source, into: out, frames: Int(frames), gain: 1)

        let url = originalSoundURL
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    /// The take, cleaned between words and brought to a dialogue level, within the same limits
    /// the dub mode allows a take to be moved.
    private static func levelledVoice(from url: URL) throws -> AVAudioPCMBuffer {
        let buffer = try DubAudioLoader.loadVoiceBuffer(from: url)
        _ = DubTakeCleanup.apply(to: buffer)
        guard let level = DubVoiceLevel.speechLevel(of: buffer), level > 0,
              let samples = buffer.floatChannelData?[0] else { return buffer }
        let gain = min(DubVoiceLevel.maximumBoost, max(DubVoiceLevel.maximumCut, voiceTarget / level))
        for index in 0..<Int(buffer.frameLength) { samples[index] *= gain }
        return buffer
    }

    /// Decodes the clip's own sound to mono and adds it at `gain`, placed by each
    /// buffer's timestamp so an audio track that starts late still lines up with the picture.
    private static func addOriginal(
        of source: Source,
        into out: UnsafeMutablePointer<Float>,
        frames: Int,
        gain: Float
    ) async throws {
        let asset = AVURLAsset(url: source.url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return }

        let reader: AVAssetReader
        do { reader = try AVAssetReader(asset: asset) } catch { throw MixError.readFailed(error) }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false
        ])
        reader.add(output)
        reader.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: source.duration, preferredTimescale: 600)
        )
        guard reader.startReading() else { throw MixError.readFailed(reader.error) }

        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            let start = Int((CMSampleBufferGetPresentationTimeStamp(sample).seconds * sampleRate).rounded())
            var length = 0
            var pointer: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil,
                                              totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
                  let pointer else { continue }
            let count = length / MemoryLayout<Float>.size
            pointer.withMemoryRebound(to: Float.self, capacity: count) { samples in
                for index in 0..<count {
                    let target = start + index
                    guard target >= 0, target < frames else { continue }
                    out[target] += samples[index] * gain
                }
            }
        }
        if reader.status == .failed { throw MixError.readFailed(reader.error) }
    }

    private static func writeSoundtrack(_ buffer: AVAudioPCMBuffer, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        // Scoped so the file is closed, and its last packets flushed, before it is read back.
        do {
            let file = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000
            ], commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        }
    }

    /// The clip's picture and the new soundtrack, remuxed without re-encoding.
    private static func remux(source: Source, soundtrack: URL, to outputURL: URL) async throws -> URL {
        let clip = AVURLAsset(url: source.url)
        let sound = AVURLAsset(url: soundtrack)
        guard let picture = try await clip.loadTracks(withMediaType: .video).first else { throw MixError.noPicture }

        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: source.duration, preferredTimescale: 600))
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw MixError.exportFailed(nil) }
        try videoTrack.insertTimeRange(range, of: picture, at: .zero)
        videoTrack.preferredTransform = try await picture.load(.preferredTransform)

        if let voiceTrack = try await sound.loadTracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let soundDuration = try await sound.load(.duration)
            let audioRange = CMTimeRange(start: .zero, duration: CMTimeMinimum(soundDuration, range.duration))
            try audioTrack.insertTimeRange(audioRange, of: voiceTrack, at: .zero)
        }

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)
        else { throw MixError.exportFailed(nil) }

        // Phone footage is H.264 or HEVC, which MP4 carries; anything MP4 can't hold goes out
        // as a QuickTime movie rather than failing.
        let fileType: AVFileType = session.supportedFileTypes.contains(.mp4) ? .mp4 : .mov
        let destination = outputURL.deletingPathExtension()
            .appendingPathExtension(fileType == .mp4 ? "mp4" : "mov")
        try? FileManager.default.removeItem(at: destination)
        session.outputURL = destination
        session.outputFileType = fileType

        // Awaited inline, as in `DubMixer.write`: an async wrapper is a hop Swift 6 reads as
        // sending the session away.
        await withCheckedContinuation { continuation in
            session.exportAsynchronously { continuation.resume() }
        }
        guard session.status == .completed else { throw MixError.exportFailed(session.error) }
        return destination
    }
}
