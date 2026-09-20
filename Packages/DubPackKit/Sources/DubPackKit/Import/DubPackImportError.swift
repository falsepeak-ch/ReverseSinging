//
//  DubPackImportError.swift
//  DubPackKit
//

public import Foundation

/// Why a pack could not be imported at all.
///
/// Messages are the host app's business: switch over the cases and say it in the user's
/// language. `telemetryCode` is the stable, English name of each case for crash reporting.
public enum DubPackImportError: Error, Sendable, Hashable {
    /// Nothing exists at the location the import was given, or it cannot be listed.
    case sourceMissing
    /// A file that is neither a folder nor an archive this package opens. Carries its
    /// extension, lower-cased, or an empty string when it has none, and what its first bytes
    /// say it really is (`html`, `mp4`, `empty`), which is the only clue there is when a
    /// `.zip` is not a zip.
    case unsupportedSource(fileExtension: String, looksLike: String? = nil)
    /// The file is in iCloud and not on the device, and did not download in time. The user
    /// has to open it in Files first, or wait for it.
    case sourceNotDownloaded
    /// An archive that would not unpack.
    case archiveUnreadable(ArchiveFailure)
    /// Nothing in the folder or archive looks like a pack.
    case noPackFound
    /// A pack was found, but not one entry in it became a line. Carries everything the reader
    /// found wrong, which is the only explanation there will be.
    case noLines(issues: [DubPackIssue])
    /// The file system refused: no space left, no permission. Carries the system's message.
    case installFailed(detail: String)
    /// The task running the import was cancelled.
    case cancelled

    public var telemetryCode: String {
        switch self {
        case .sourceMissing: "source_missing"
        case .unsupportedSource: "unsupported_source"
        case .sourceNotDownloaded: "source_not_downloaded"
        case .archiveUnreadable(let failure): "archive.\(failure.telemetryCode)"
        case .noPackFound: "no_pack_found"
        case .noLines: "no_lines"
        case .installFailed: "install_failed"
        case .cancelled: "cancelled"
        }
    }

    /// True for a failure of the device or the moment rather than of the pack: no storage
    /// left, a file iCloud has not delivered. Nothing about the format to learn from it.
    public var isEnvironmental: Bool {
        switch self {
        case .sourceNotDownloaded, .cancelled:
            true
        case .archiveUnreadable(.io), .archiveUnreadable(.outOfMemory), .archiveUnreadable(.tooLarge):
            true
        case .installFailed(let detail):
            detail.localizedCaseInsensitiveContains("space") || detail.localizedCaseInsensitiveContains("ENOSPC")
        case .unsupportedSource(_, let looksLike):
            looksLike == "icloud_placeholder" || looksLike == "empty"
        default:
            false
        }
    }

    /// Free-form English detail for crash reports, when the case carries any.
    public var detail: String? {
        switch self {
        case .unsupportedSource(let fileExtension, let looksLike):
            // `rar (rar)` says nothing twice; only a disagreement is worth the parenthesis.
            looksLike.map { $0 == fileExtension ? fileExtension : "\(fileExtension) (\($0))" } ?? fileExtension
        case .archiveUnreadable(let failure): failure.detail
        case .installFailed(let detail): detail
        case .sourceMissing, .sourceNotDownloaded, .noPackFound, .noLines, .cancelled: nil
        }
    }
}

/// Why an archive would not unpack.
public enum ArchiveFailure: Sendable, Hashable {
    /// The file does not carry the signature of the format it was opened as.
    case notAnArchive
    /// Truncated or damaged beyond recovering a single entry. Carries the reader's own reason.
    case corrupt(detail: String)
    /// A compression method the decoder does not have.
    case unsupportedMethod(detail: String)
    /// The contents are password protected.
    case encrypted
    /// A block too large to decode in the memory this device has.
    case tooLarge(detail: String)
    case outOfMemory
    /// Reading the archive or writing what it holds failed.
    case io(detail: String)

    public var telemetryCode: String {
        switch self {
        case .notAnArchive: "not_an_archive"
        case .corrupt: "corrupt"
        case .unsupportedMethod: "unsupported_method"
        case .encrypted: "encrypted"
        case .tooLarge: "too_large"
        case .outOfMemory: "out_of_memory"
        case .io: "io"
        }
    }

    public var detail: String? {
        switch self {
        case .corrupt(let detail), .unsupportedMethod(let detail), .tooLarge(let detail), .io(let detail):
            detail
        case .notAnArchive, .encrypted, .outOfMemory:
            nil
        }
    }
}

extension DubPackImportError: CustomNSError {
    public static var errorDomain: String { "DubPackKit.DubPackImportError" }

    /// Stable per case, so crash reporting groups each failure separately. Never renumber.
    public var errorCode: Int {
        switch self {
        case .sourceMissing: 1
        case .unsupportedSource: 2
        case .archiveUnreadable: 3
        case .noPackFound: 4
        case .noLines: 5
        case .installFailed: 6
        case .cancelled: 7
        case .sourceNotDownloaded: 8
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = ["telemetry_code": telemetryCode]
        if let detail { info["detail"] = detail }
        return info
    }
}
