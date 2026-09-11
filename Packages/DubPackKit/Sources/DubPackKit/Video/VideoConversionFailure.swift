//
//  VideoConversionFailure.swift
//  DubPackKit
//

public import Foundation

/// Why a Theora scene could not be converted to H.264.
public enum VideoConversionFailure: Error, Sendable, Hashable {
    /// The source could not be opened, or the old output could not be cleared.
    case unreadableSource(detail: String)
    /// No Theora stream in the file.
    case notTheora
    /// The Theora headers are incomplete or describe an impossible picture.
    case badHeaders
    case decoderUnavailable
    case unsupportedPixelFormat
    /// The stream decoded to no frames at all.
    case noFrames
    /// AVFoundation's writer refused. Carries its message.
    case writerFailed(detail: String)
    /// The file on disk is not the length the decoder wrote. The one failure that would
    /// otherwise play: every line after the missing frames would run early.
    case lengthMismatch(expected: TimeInterval, actual: TimeInterval)

    public var telemetryName: String {
        switch self {
        case .unreadableSource: "unreadable_source"
        case .notTheora: "not_theora"
        case .badHeaders: "bad_headers"
        case .decoderUnavailable: "decoder_unavailable"
        case .unsupportedPixelFormat: "unsupported_pixel_format"
        case .noFrames: "no_frames"
        case .writerFailed: "writer_failed"
        case .lengthMismatch: "length_mismatch"
        }
    }

    /// Free-form English detail for crash reports, when the case carries any.
    public var detail: String? {
        switch self {
        case .unreadableSource(let detail), .writerFailed(let detail): detail
        case .lengthMismatch(let expected, let actual):
            String(format: "wrote %.2fs, expected %.2fs", actual, expected)
        case .notTheora, .badHeaders, .decoderUnavailable, .unsupportedPixelFormat, .noFrames: nil
        }
    }
}
