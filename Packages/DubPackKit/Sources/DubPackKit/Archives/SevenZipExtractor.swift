//
//  SevenZipExtractor.swift
//  DubPackKit
//

import CArchives
import Foundation

/// Unpacks a `.7z` archive through the vendored LZMA SDK decoder.
///
/// 7-Zip is what a Windows pack author reaches for first. The C side streams the common block
/// types straight to disk, checks every file's CRC, refuses `..` paths, and decodes only the rare
/// exotic blocks in memory, up to `inMemoryBlockLimit`.
enum SevenZipExtractor {

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
        var stats = SevenZipExtractStats(entriesWritten: 0, entriesSkipped: 0)

        let status = archive.withUnsafeFileSystemRepresentation { archivePath in
            destination.withUnsafeFileSystemRepresentation { destinationPath -> SevenZipStatus in
                guard let archivePath, let destinationPath else { return SevenZipStatusIO }
                return withExtendedLifetime(relay) {
                    SevenZipExtract(
                        archivePath,
                        destinationPath,
                        inMemoryBlockLimit,
                        { context, written, total in
                            guard let context else { return 0 }
                            let relay = Unmanaged<ExtractionProgressRelay>.fromOpaque(context).takeUnretainedValue()
                            return relay.report(done: written, total: total) ? 0 : 1
                        },
                        Unmanaged.passUnretained(relay).toOpaque(),
                        &detail,
                        detail.count,
                        &stats
                    )
                }
            }
        }

        let message = String(cBuffer: detail)

        switch status {
        case SevenZipStatusOK: return ExtractionSummary(skippedEntries: Int(stats.entriesSkipped))
        case SevenZipStatusCancelled: throw .cancelled
        case SevenZipStatusNotAnArchive: throw .failed(.notAnArchive)
        case SevenZipStatusUnsupported: throw .failed(.unsupportedMethod(detail: message))
        case SevenZipStatusEncrypted: throw .failed(.encrypted)
        case SevenZipStatusOutOfMemory: throw .failed(.outOfMemory)
        case SevenZipStatusTooLarge: throw .failed(.tooLarge(detail: message))
        case SevenZipStatusIO: throw .failed(.io(detail: message))
        default: throw .failed(.corrupt(detail: message))
        }
    }

    /// The largest solid block the decoder may unpack in memory, which it only does for the
    /// methods it cannot stream (PPMd, filtered blocks). Half of what the process may still take
    /// on iOS, so a huge exotic archive is refused with a message rather than ended by the system
    /// killing the app.
    private static var inMemoryBlockLimit: Int {
        #if os(iOS)
        let available = os_proc_available_memory()
        return available > 0 ? available / 2 : 256 << 20
        #else
        return Int(ProcessInfo.processInfo.physicalMemory / 4)
        #endif
    }
}
