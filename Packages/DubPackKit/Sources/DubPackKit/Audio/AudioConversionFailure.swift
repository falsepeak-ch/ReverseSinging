//
//  AudioConversionFailure.swift
//  DubPackKit
//

public import Foundation

/// Why an Ogg Vorbis recording could not be converted to AAC.
public enum AudioConversionFailure: Error, Sendable, Hashable {
    /// The file could not be opened.
    case unreadableSource(detail: String)
    /// No Vorbis stream in the file: a Theora-only `.ogg`, or something else renamed.
    case notVorbis
    /// The stream is damaged past what the decoder can skip over. Carries the decoder's code.
    case corrupt(detail: String)
    /// The stream decoded to no audio at all.
    case noSamples
    /// AVFoundation's file writer refused. Carries its message.
    case writerFailed(detail: String)
    /// The device ran out of storage partway through. Worth trying again later.
    case diskFull

    /// True for a failure of the moment rather than of the file.
    public var isRetryable: Bool { self == .diskFull }

    public var telemetryName: String {
        switch self {
        case .unreadableSource: "unreadable_source"
        case .notVorbis: "not_vorbis"
        case .corrupt: "corrupt"
        case .noSamples: "no_samples"
        case .writerFailed: "writer_failed"
        case .diskFull: "disk_full"
        }
    }

    /// Free-form English detail for crash reports, when the case carries any.
    public var detail: String? {
        switch self {
        case .unreadableSource(let detail), .corrupt(let detail), .writerFailed(let detail): detail
        case .notVorbis, .noSamples, .diskFull: nil
        }
    }

    /// The failure a file-writing error amounts to, read by code rather than by its localised message.
    static func writer(_ error: any Error) -> AudioConversionFailure {
        if case .diskFull? = VideoConversionFailure.environmental(error) { return .diskFull }
        return .writerFailed(detail: error.localizedDescription)
    }
}
