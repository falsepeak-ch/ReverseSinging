//
//  ZipRecoveryExtractor.swift
//  DubPackKit
//

import CArchives
import Foundation

/// Unpacks a zip whose index is missing or unreadable, by walking its entries from the front.
///
/// A zip keeps its table of contents at the very end of the file, so a download that stops even a
/// few bytes short loses it, and a reader that starts from that table refuses the whole archive.
/// Every entry also has a header in front of its own data, so everything before the break can
/// still be read. Entries that fail their checksum are left out.
///
/// A file the end of the archive cuts through is kept only when it is audio: a partial recording
/// plays for as long as it goes, while a partial still, entry or scene video would only mislead.
enum ZipRecoveryExtractor {

    /// Blocking: call it off the main actor. Stops with `.cancelled` when the surrounding task is.
    static func extract(
        _ archive: URL,
        to destination: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws(ExtractionError) -> ExtractionSummary {
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            throw .failed(.io(detail: error.localizedDescription))
        }

        let relay = ExtractionProgressRelay(handler: progress)
        var truncated = [CChar](repeating: 0, count: 4096)
        var detail = [CChar](repeating: 0, count: 256)
        var stats = ZipRecoverStats()

        let status = archive.withUnsafeFileSystemRepresentation { archivePath in
            destination.withUnsafeFileSystemRepresentation { destinationPath -> ZipRecoverStatus in
                guard let archivePath, let destinationPath else { return ZipRecoverStatusIO }
                return withExtendedLifetime(relay) {
                    ZipRecoverExtract(
                        archivePath,
                        destinationPath,
                        { context, read, total in
                            guard let context else { return 0 }
                            let relay = Unmanaged<ExtractionProgressRelay>.fromOpaque(context).takeUnretainedValue()
                            return relay.report(done: read, total: total) ? 0 : 1
                        },
                        Unmanaged.passUnretained(relay).toOpaque(),
                        &truncated,
                        truncated.count,
                        &detail,
                        detail.count,
                        &stats
                    )
                }
            }
        }

        let message = String(cBuffer: detail)

        switch status {
        case ZipRecoverStatusOK: break
        case ZipRecoverStatusCancelled: throw .cancelled
        case ZipRecoverStatusNotAZip: throw .failed(.notAnArchive)
        case ZipRecoverStatusEncrypted: throw .failed(.encrypted)
        case ZipRecoverStatusUnsupported: throw .failed(.unsupportedMethod(detail: message))
        case ZipRecoverStatusIO: throw .failed(.io(detail: message))
        default: throw .failed(.corrupt(detail: message))
        }

        let truncatedEntry = String(cBuffer: truncated).trimmedOrNil
        var partialKept = false
        if let truncatedEntry {
            if keepsPartial(truncatedEntry) {
                partialKept = true
            } else {
                try? FileManager.default.removeItem(at: destination.appendingPathComponent(truncatedEntry))
            }
        }

        return ExtractionSummary(
            skippedEntries: Int(stats.entriesSkipped),
            recovery: ArchiveRecovery(
                indexMissing: stats.reachedIndex == 0,
                truncatedEntry: truncatedEntry,
                partialKept: partialKept,
                damagedEntries: Int(stats.entriesDamaged)
            )
        )
    }

    /// Whether a file cut off partway is still worth having. Audio only, and not `.ogg`, which is
    /// as often a Theora scene video as a recording.
    static func keepsPartial(_ relativePath: String) -> Bool {
        let fileExtension = (relativePath as NSString).pathExtension.lowercased()
        return PackFormat.Files.audioExtensions.contains(fileExtension)
            && !PackFormat.Files.videoExtensions.contains(fileExtension)
    }
}
