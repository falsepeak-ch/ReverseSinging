//
//  RarExtractor.swift
//  DubPackKit
//

import CArchives
import Foundation

/// Unpacks a `.rar` archive, RAR 4 or RAR 5, through the vendored libarchive readers.
///
/// WinRAR is as common on a pack author's PC as 7-Zip, and an upload form that only takes
/// `.zip` gets a `.rar` renamed to one: the most imported file that would not open was exactly
/// that. The C side decodes straight to disk a block at a time, refuses `..` paths, skips
/// anything that is not a regular file, and keeps every entry that came out whole when the
/// archive is damaged or was cut off, the same bargain `ZipRecoveryExtractor` makes.
///
/// Not supported, and refused as such: passwords, and archives split into volumes.
enum RarExtractor {

    /// Blocking and CPU-bound: call it off the main actor. Stops with `.cancelled` when the
    /// surrounding task is cancelled.
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
        var detail = [CChar](repeating: 0, count: 256)
        var damagedEntry = [CChar](repeating: 0, count: 1024)
        var stats = RarExtractStats(entriesWritten: 0, entriesSkipped: 0, entriesDamaged: 0, truncated: 0)

        let status = archive.withUnsafeFileSystemRepresentation { archivePath in
            destination.withUnsafeFileSystemRepresentation { destinationPath -> RarStatus in
                guard let archivePath, let destinationPath else { return RarStatusIO }
                return withExtendedLifetime(relay) {
                    RarExtract(
                        archivePath,
                        destinationPath,
                        { context, read, total in
                            guard let context else { return 0 }
                            let relay = Unmanaged<ExtractionProgressRelay>.fromOpaque(context).takeUnretainedValue()
                            return relay.report(done: read, total: total) ? 0 : 1
                        },
                        Unmanaged.passUnretained(relay).toOpaque(),
                        &detail,
                        detail.count,
                        &damagedEntry,
                        damagedEntry.count,
                        &stats
                    )
                }
            }
        }

        let message = String(cBuffer: detail)

        switch status {
        case RarStatusOK:
            var summary = ExtractionSummary(skippedEntries: Int(stats.entriesSkipped))
            if stats.truncated != 0 || stats.entriesDamaged > 0 {
                let entry = String(cBuffer: damagedEntry)
                summary.recovery = ArchiveRecovery(
                    indexMissing: stats.truncated != 0,
                    truncatedEntry: entry.isEmpty ? nil : entry,
                    // A RAR entry is one compressed stream: what comes out of a broken one is
                    // not the start of a recording, so nothing partial is ever kept.
                    partialKept: false,
                    damagedEntries: Int(stats.entriesDamaged)
                )
            }
            return summary
        case RarStatusCancelled: throw .cancelled
        case RarStatusNotAnArchive: throw .failed(.notAnArchive)
        case RarStatusUnsupported: throw .failed(.unsupportedMethod(detail: message))
        case RarStatusEncrypted: throw .failed(.encrypted)
        case RarStatusOutOfMemory: throw .failed(.outOfMemory)
        case RarStatusIO: throw .failed(.io(detail: message))
        default: throw .failed(.corrupt(detail: message))
        }
    }
}
