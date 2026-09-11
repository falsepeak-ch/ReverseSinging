//
//  PackInstallation.swift
//  DubPackKit
//

import Foundation

/// Puts a pack into the library without ever leaving one half there.
///
/// The pack is assembled in a hidden `.incoming-<uuid>` folder inside the library, where the
/// video is converted and the pack is read. Only once that has worked does it replace any
/// installed pack of the same name. A failed re-import therefore leaves the previous install,
/// and the takes recorded against it, exactly as they were. Hidden folders are invisible to
/// anything that lists the library with `.skipsHiddenFiles`.
struct PackInstallation: Sendable {

    let libraryDirectory: URL
    /// Lower-cased names never copied from a source, such as the host's own cache file.
    let ignoredFileNames: Set<String>

    private static let incomingPrefix = ".incoming-"
    private static let retiredPrefix = ".retired-"
    /// Staging folders older than this belong to an import that crashed.
    private static let abandonedAge: TimeInterval = 60 * 60

    init(libraryDirectory: URL, ignoredFileNames: Set<String>) {
        self.libraryDirectory = libraryDirectory
        self.ignoredFileNames = Set(ignoredFileNames.map { $0.lowercased() })
    }

    // MARK: - Naming

    /// The folder a source installs under: a folder's own name, an archive's name without its
    /// extension, with characters no file system accepts replaced.
    static func folderName(for source: URL) -> String {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory)
        let name = exists && isDirectory.boolValue
            ? source.lastPathComponent
            : source.deletingPathExtension().lastPathComponent

        let cleaned = name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop { $0 == "." }

        return cleaned.isEmpty ? "DubPack" : String(cleaned)
    }

    func destination(forFolderName folderName: String) -> URL {
        libraryDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    // MARK: - Steps

    /// Makes sure the library exists and clears staging folders left by a crashed import.
    func prepareLibrary() throws(DubPackImportError) {
        do {
            try FileManager.default.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
        } catch {
            throw .installFailed(detail: error.localizedDescription)
        }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: libraryDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        )) ?? []

        for item in contents {
            let name = item.lastPathComponent
            guard name.hasPrefix(Self.incomingPrefix) || name.hasPrefix(Self.retiredPrefix) else { continue }
            let created = (try? item.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if Date().timeIntervalSince(created) > Self.abandonedAge {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }

    /// Assembles the pack at `root` in a hidden staging folder and returns it. Items are moved
    /// out of a temporary unpacking, which is much faster for a large pack, and copied from a
    /// folder the user chose.
    func assemble(from root: URL, moving: Bool) throws(DubPackImportError) -> URL {
        let incoming = libraryDirectory.appendingPathComponent(
            Self.incomingPrefix + UUID().uuidString,
            isDirectory: true
        )
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: incoming, withIntermediateDirectories: true)
            let items = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            for item in items where !isIgnored(item.lastPathComponent) {
                let target = incoming.appendingPathComponent(item.lastPathComponent)
                if moving {
                    try fileManager.moveItem(at: item, to: target)
                } else {
                    try fileManager.copyItem(at: item, to: target)
                }
            }
            return incoming
        } catch {
            try? fileManager.removeItem(at: incoming)
            throw .installFailed(detail: error.localizedDescription)
        }
    }

    /// Replaces any installed pack called `folderName` with the assembled one.
    func commit(_ incoming: URL, as folderName: String) throws(DubPackImportError) -> URL {
        let destination = destination(forFolderName: folderName)
        let fileManager = FileManager.default

        do {
            guard fileManager.fileExists(atPath: destination.path) else {
                try fileManager.moveItem(at: incoming, to: destination)
                return destination
            }

            let retired = libraryDirectory.appendingPathComponent(
                Self.retiredPrefix + UUID().uuidString,
                isDirectory: true
            )
            try fileManager.moveItem(at: destination, to: retired)
            do {
                try fileManager.moveItem(at: incoming, to: destination)
            } catch {
                try? fileManager.moveItem(at: retired, to: destination)
                throw error
            }
            try? fileManager.removeItem(at: retired)
            return destination
        } catch {
            throw .installFailed(detail: error.localizedDescription)
        }
    }

    func discard(_ incoming: URL) {
        try? FileManager.default.removeItem(at: incoming)
    }

    private func isIgnored(_ name: String) -> Bool {
        let key = name.lowercased()
        return ignoredFileNames.contains(key) || PackFormat.Files.clutter.contains(key)
    }
}
