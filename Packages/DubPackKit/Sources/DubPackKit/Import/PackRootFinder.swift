//
//  PackRootFinder.swift
//  DubPackKit
//

import Foundation

/// Finds the pack inside whatever it arrived wrapped in.
///
/// Files at the archive root, one wrapping folder (what "compress this folder" produces), or a
/// folder inside that (an archive of a release folder). Searched breadth first, so the shallowest
/// folder with a pack info file wins. Without one anywhere, the folder with the most numbered line
/// entries does.
enum PackRootFinder {

    /// How many folders deep a pack may sit. Deeper than this is a different thing being imported.
    static let maxDepth = 3

    static func root(in directory: URL, maxDepth: Int = maxDepth) -> URL? {
        var best: (url: URL, numberedEntries: Int)?

        for folder in folders(in: directory, maxDepth: maxDepth) {
            if folder.packInfoFile != nil { return folder.url }

            let numbered = folder.numberedEntryCount
            if numbered > (best?.numberedEntries ?? 0) {
                best = (folder.url, numbered)
            }
        }

        return best?.url
    }

    /// How many files there are of each extension anywhere within reach. What a folder holds is the
    /// only explanation there is when no pack is found in it.
    static func fileTypeCounts(in directory: URL, maxDepth: Int = maxDepth) -> [String: Int] {
        folders(in: directory, maxDepth: maxDepth).reduce(into: [:]) { counts, folder in
            counts.merge(folder.fileTypeCounts, uniquingKeysWith: +)
        }
    }

    /// `directory` and the folders under it, breadth first, skipping what operating systems leave behind.
    private static func folders(in directory: URL, maxDepth: Int) -> [PackDirectory] {
        var queue: [(url: URL, depth: Int)] = [(directory, 0)]
        var folders: [PackDirectory] = []

        while !queue.isEmpty {
            let (url, depth) = queue.removeFirst()
            guard let folder = PackDirectory(url: url) else { continue }
            folders.append(folder)

            if depth < maxDepth {
                queue += subdirectories(of: url).map { ($0, depth + 1) }
            }
        }
        return folders
    }

    private static func subdirectories(of url: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .filter { !PackFormat.Files.clutter.contains($0.lastPathComponent.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
