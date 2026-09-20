//
//  SourceAvailability.swift
//  DubPackKit
//

import Foundation

/// Makes sure a source chosen from Files is actually on the device before it is read.
///
/// A pack in iCloud Drive that was never opened on this device is a placeholder: the file
/// picker hands over a URL that exists, is a few hundred bytes of property list, and is not a
/// zip. A folder in the same state lists as empty, its files standing in as hidden
/// `.name.icloud` stubs. Both used to fail as "not a pack" with nothing to say why.
enum SourceAvailability {

    /// How long to wait for iCloud. A pack is tens of megabytes; on a poor connection that
    /// is a minute or two, and the progress overlay is up the whole time.
    static let timeout: TimeInterval = 120
    static let pollInterval: TimeInterval = 0.3

    /// Starts downloading whatever in `source` is not here yet, and waits for it.
    ///
    /// Blocking: call it off the main actor. Nothing happens for a source that is local.
    static func ensureDownloaded(_ source: URL, timeout: TimeInterval = timeout) throws(DubPackImportError) {
        var pending = placeholders(under: source)
        guard !pending.isEmpty else { return }

        for item in pending {
            try? FileManager.default.startDownloadingUbiquitousItem(at: item)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while !pending.isEmpty, Date() < deadline {
            if Task.isCancelled { throw .cancelled }
            Thread.sleep(forTimeInterval: pollInterval)
            pending = placeholders(under: source)
        }

        if !pending.isEmpty { throw .sourceNotDownloaded }
    }

    /// `source` itself when it is an iCloud item that has not come down, and every such item
    /// within reach inside it when it is a folder, `.icloud` stubs included.
    static func placeholders(under source: URL) -> [URL] {
        var result: [URL] = []
        if isNotDownloaded(source) { result.append(source) }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return result
        }

        var queue: [(url: URL, depth: Int)] = [(source, 0)]
        while !queue.isEmpty {
            let (folder, depth) = queue.removeFirst()
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isDirectoryKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
                options: []
            )) ?? []

            for item in contents {
                let isFolder = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                if isFolder {
                    if depth < PackRootFinder.maxDepth { queue.append((item, depth + 1)) }
                } else if item.pathExtension.lowercased() == "icloud" || isNotDownloaded(item) {
                    result.append(item)
                }
            }
        }
        return result
    }

    private static func isNotDownloaded(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true,
              let status = values.ubiquitousItemDownloadingStatus else {
            return false
        }
        return status != .current && status != .downloaded
    }
}
