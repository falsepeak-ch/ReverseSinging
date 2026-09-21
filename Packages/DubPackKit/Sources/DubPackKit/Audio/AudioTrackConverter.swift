//
//  AudioTrackConverter.swift
//  DubPackKit
//

import AVFoundation
import Foundation

/// Converts a pack's Ogg Vorbis recordings to AAC, in place, so that everything downstream
/// deals in audio AVFoundation reads.
///
/// Half the pack tools in the wild write their lines and their backing track as `.ogg`, which
/// no Apple framework decodes. Until this existed those packs imported with every line dropped
/// as unplayable, or with a silent scene, and read to their authors as a broken app. Decoding is
/// libvorbis; encoding is AVFoundation's AAC through `AVAudioFile`, the same codec the app's own
/// pack builder uses for a backing track.
enum AudioTrackConverter {

    struct Outcome: Sendable, Equatable {
        var converted: [String] = []
        var issues: [DubPackIssue] = []
    }

    /// Container extensions that hold Vorbis when they hold audio.
    static let vorbisExtensions: Set<String> = ["ogg", "oga"]

    /// The audio files in `directory` that need converting: every Vorbis container other than
    /// one standing as the scene video.
    ///
    /// Converted whether or not this platform happens to decode Vorbis (a Mac running the
    /// tests may; the phones in the crash reports do not), so a pack ends up the same on
    /// every device and its lines are measured from the same files.
    static func candidates(in folder: PackDirectory) -> [PackFile] {
        let video: PackFile? = if case .found(let file) = folder.sceneVideo { file } else { nil }
        return folder.files.filter { file in
            vorbisExtensions.contains(file.fileExtension) && file.name != video?.name
        }
    }

    /// True when `directory` holds audio this converter would convert.
    static func hasPendingConversion(in directory: URL) -> Bool {
        guard let folder = PackDirectory(url: directory) else { return false }
        return !candidates(in: folder).isEmpty
    }

    /// Converts every candidate in `directory`, replacing `name.ogg` with `name.m4a`.
    ///
    /// Blocking and CPU-bound: call it off the main actor. A source that converts is deleted;
    /// one that does not is left where it was, so the reader can still say what was there.
    static func convertIfNeeded(
        in directory: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) -> Outcome {
        guard let folder = PackDirectory(url: directory) else { return Outcome() }
        let sources = candidates(in: folder)
        guard !sources.isEmpty else { return Outcome() }

        var outcome = Outcome()
        for (offset, source) in sources.enumerated() {
            if Task.isCancelled { break }
            let destination = directory.appendingPathComponent(source.stem + ".m4a")

            do throws(AudioConversionFailure) {
                // A same-named `.m4a` already there is the better file; the Vorbis copy only
                // ever shadowed it in the lookup order.
                if !FileManager.default.fileExists(atPath: destination.path) {
                    try convert(source.url, to: destination)
                }
                try? FileManager.default.removeItem(at: source.url)
                outcome.converted.append(source.name)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                // A Theora-only `.ogg` is not audio at all, and not this converter's problem.
                if error != .notVorbis {
                    outcome.issues.append(.audioConversionFailed(file: source.name, failure: error))
                }
            }
            progress?(Double(offset + 1) / Double(sources.count))
        }
        return outcome
    }

    /// Decodes `source` and writes an AAC `.m4a` to `destination`, replacing anything there.
    static func convert(_ source: URL, to destination: URL) throws(AudioConversionFailure) {
        var decoder = try VorbisDecoder(url: source)
        defer { decoder.close() }

        let writer: AVAudioFile
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            writer = try AVAudioFile(
                forWriting: destination,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: decoder.format.sampleRate,
                    AVNumberOfChannelsKey: decoder.format.channelCount,
                    AVEncoderBitRateKey: bitRate(channels: decoder.format.channelCount),
                ],
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            throw AudioConversionFailure.writer(error)
        }

        var frames: AVAudioFramePosition = 0
        while let buffer = try decoder.next() {
            do {
                try writer.write(from: buffer)
            } catch {
                throw AudioConversionFailure.writer(error)
            }
            frames += AVAudioFramePosition(buffer.frameLength)
        }
        guard frames > 0 else { throw .noSamples }
    }

    /// Speech at 96 kbps mono is transparent; a stereo backing track gets 160.
    private static func bitRate(channels: AVAudioChannelCount) -> Int {
        channels > 1 ? 160_000 : 96_000
    }
}
