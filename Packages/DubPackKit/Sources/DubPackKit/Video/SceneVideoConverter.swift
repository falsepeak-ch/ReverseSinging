//
//  SceneVideoConverter.swift
//  DubPackKit
//

import Foundation

/// Converts a pack's Theora scene video to H.264, in place, when it has one.
enum SceneVideoConverter {

    enum Outcome: Sendable, Equatable {
        case nothingToConvert
        case converted(file: String)
        /// The scene will show its stills. Neither the source nor a partial output is left behind.
        case failed(file: String, failure: VideoConversionFailure)
    }

    static let convertedFileName = "dub_video.mp4"

    static func convertIfNeeded(
        in directory: URL,
        probe: any MediaProbe,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async -> Outcome {
        guard let folder = PackDirectory(url: directory),
              case .found(let source) = folder.sceneVideo,
              PackFormat.Files.theoraExtensions.contains(source.fileExtension) else {
            return .nothingToConvert
        }

        let destination = directory.appendingPathComponent(convertedFileName)

        do throws(VideoConversionFailure) {
            let written = try TheoraTranscoder.transcode(ogv: source.url, to: destination, progress: progress)

            // Check what landed on disk against what the decoder says it wrote. A video that
            // comes out short plays, looks fine, and puts every line after the missing frames
            // early, which is how a dropped-duplicate-frame bug once shipped unnoticed.
            let measured = await probe.videoDuration(of: destination) ?? 0
            let tolerance = max(0.05, written.duration * 0.001)
            guard abs(measured - written.duration) <= tolerance else {
                throw .lengthMismatch(expected: written.duration, actual: measured)
            }

            // The Theora original is by far the largest file in a pack and useless once
            // converted, so it does not get to sit in the user's storage.
            try? FileManager.default.removeItem(at: source.url)
            return .converted(file: convertedFileName)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.removeItem(at: source.url)
            return .failed(file: source.name, failure: error)
        }
    }
}
