//
//  StagedSource.swift
//  DubPackKit
//

import Foundation

/// A pack source turned into a plain directory: an archive unpacked into a temporary folder, or a
/// folder passed through as it is.
struct StagedSource: Sendable {
    let directory: URL
    /// True when `directory` is a temporary unpacking this import owns and may consume.
    let isTemporary: Bool
    let skippedEntries: Int
    /// Set when a zip had to be recovered entry by entry.
    let recovery: ArchiveRecovery?

    /// Removes the temporary unpacking. A folder the user chose is never touched.
    func discard() {
        guard isTemporary else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    static func stage(
        _ source: URL,
        temporaryRoot: URL,
        progress: (@Sendable (Double) -> Void)?
    ) throws(DubPackImportError) -> StagedSource {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw .sourceMissing
        }

        if isDirectory.boolValue {
            // `fileExists` follows a symbolic link, but the directory reads after it do not: a link
            // to a pack folder would list as empty and be refused as holding no pack.
            let folder = source.resolvingSymlinksInPath()
            return StagedSource(directory: folder, isTemporary: false, skippedEntries: 0, recovery: nil)
        }

        guard let kind = ArchiveKind.detect(at: source) else {
            throw .unsupportedSource(fileExtension: source.pathExtension.lowercased())
        }

        let unpacked = temporaryRoot.appendingPathComponent("dubpack-\(UUID().uuidString)", isDirectory: true)

        do throws(ExtractionError) {
            let summary = switch kind {
            case .zip: try ZipExtractor.extract(source, to: unpacked, progress: progress)
            case .sevenZip: try SevenZipExtractor.extract(source, to: unpacked, progress: progress)
            }
            return StagedSource(
                directory: unpacked,
                isTemporary: true,
                skippedEntries: summary.skippedEntries,
                recovery: summary.recovery
            )
        } catch {
            try? FileManager.default.removeItem(at: unpacked)
            switch error {
            case .cancelled: throw .cancelled
            case .failed(let failure): throw .archiveUnreadable(failure)
            }
        }
    }
}
