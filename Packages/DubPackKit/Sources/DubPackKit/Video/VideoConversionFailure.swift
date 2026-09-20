//
//  VideoConversionFailure.swift
//  DubPackKit
//

import AVFoundation
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
    /// The system took the hardware encoder away, which it does the moment the app leaves the
    /// foreground. Nothing is wrong with the file; the conversion is worth trying again.
    case interrupted
    /// The device ran out of storage partway through. Again, worth trying again later.
    case diskFull
    /// The file on disk is not the length the decoder wrote. The one failure that would
    /// otherwise play: every line after the missing frames would run early.
    case lengthMismatch(expected: TimeInterval, actual: TimeInterval)

    /// True for failures of the moment rather than of the file, where keeping the Theora
    /// original and converting it on a later launch will very likely work.
    public var isRetryable: Bool {
        switch self {
        case .interrupted, .diskFull: true
        default: false
        }
    }

    public var telemetryName: String {
        switch self {
        case .unreadableSource: "unreadable_source"
        case .notTheora: "not_theora"
        case .badHeaders: "bad_headers"
        case .decoderUnavailable: "decoder_unavailable"
        case .unsupportedPixelFormat: "unsupported_pixel_format"
        case .noFrames: "no_frames"
        case .writerFailed: "writer_failed"
        case .interrupted: "interrupted"
        case .diskFull: "disk_full"
        case .lengthMismatch: "length_mismatch"
        }
    }

    /// Free-form English detail for crash reports, when the case carries any.
    public var detail: String? {
        switch self {
        case .unreadableSource(let detail), .writerFailed(let detail): detail
        case .lengthMismatch(let expected, let actual):
            String(format: "wrote %.2fs, expected %.2fs", actual, expected)
        case .notTheora, .badHeaders, .decoderUnavailable, .unsupportedPixelFormat, .noFrames, .interrupted, .diskFull: nil
        }
    }

    /// The failure an `AVAssetWriter` error amounts to.
    ///
    /// Read by code rather than message: the message arrives in the user's language, so
    /// "Operation Interrupted", "Operación interrumpida" and "Vorgang unterbrochen" would
    /// otherwise be three different failures.
    static func writer(_ error: (any Error)?) -> VideoConversionFailure {
        guard let error else { return .writerFailed(detail: "unknown") }
        if let failure = environmental(error) { return failure }
        return .writerFailed(detail: error.localizedDescription)
    }

    /// `.interrupted` or `.diskFull` when `error`, or any error underlying it, says so.
    static func environmental(_ error: any Error) -> VideoConversionFailure? {
        let nsError = error as NSError
        switch (nsError.domain, nsError.code) {
        // AVErrorOperationInterrupted and AVErrorSessionWasInterrupted. By number because the
        // Swift names are not exported on every SDK this package builds against.
        case (AVFoundationErrorDomain, -11847), (AVFoundationErrorDomain, -11818):
            return .interrupted
        // AVErrorDiskFull, ENOSPC, NSFileWriteOutOfSpaceError.
        case (AVFoundationErrorDomain, -11807),
             (NSPOSIXErrorDomain, Int(ENOSPC)),
             (NSCocoaErrorDomain, CocoaError.fileWriteOutOfSpace.rawValue):
            return .diskFull
        default:
            break
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? any Error {
            return environmental(underlying)
        }
        return nil
    }
}
