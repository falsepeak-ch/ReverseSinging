//
//  ZipExtractor.swift
//  DubPackKit
//

import Foundation
import ZIPFoundation

/// Unpacks a `.zip` archive.
///
/// ZIPFoundation first: it reads the archive's index and checks every entry against it. When it
/// refuses the archive, `ZipRecoveryExtractor` reads the entries from the front of the file instead.
/// The usual reasons are a download that stopped short and took the index at the end with it, an
/// entry failing its checksum, and a folder entry with no permission bits, which zips written by
/// scripts and web tools often have and which ZIPFoundation creates as a folder it cannot write into.
enum ZipExtractor {

    /// Blocking: call it off the main actor.
    static func extract(
        _ archive: URL,
        to destination: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws(ExtractionError) -> ExtractionSummary {
        let refusal: String
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: archive, to: destination)
            guard !Task.isCancelled else { throw ExtractionError.cancelled }
            progress?(1)
            return ExtractionSummary(skippedEntries: 0)
        } catch ExtractionError.cancelled {
            throw .cancelled
        } catch {
            refusal = String(describing: error)
        }

        // From an empty folder: ZIPFoundation may have written part of the archive before it stopped.
        removeUnpacking(at: destination)

        do throws(ExtractionError) {
            return try ZipRecoveryExtractor.extract(archive, to: destination, progress: progress)
        } catch {
            switch error {
            case .failed(.notAnArchive), .failed(.corrupt):
                // Neither reader could make anything of it, and ZIPFoundation's reason is the more telling.
                throw .failed(.corrupt(detail: refusal))
            default:
                throw error
            }
        }
    }

    /// Removes a partial unpacking, first giving back the permissions ZIPFoundation may have taken
    /// away from its folders, since a folder that cannot be read cannot be emptied.
    private static func removeUnpacking(at url: URL) {
        let fileManager = FileManager.default
        var folders = [url]
        while let folder = folders.popLast() {
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
            let children = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            folders += children.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        }
        try? fileManager.removeItem(at: url)
    }
}
