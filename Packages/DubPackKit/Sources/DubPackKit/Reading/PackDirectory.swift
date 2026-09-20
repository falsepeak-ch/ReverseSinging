//
//  PackDirectory.swift
//  DubPackKit
//

import Foundation

/// A file in a pack, with the name the pack refers to it by: its path relative to the pack
/// folder, which for everything but the rare nested asset is just its file name.
struct PackFile: Sendable, Hashable {
    let url: URL
    let name: String

    var stem: String { (name as NSString).deletingPathExtension }
    var fileExtension: String { (name as NSString).pathExtension.lowercased() }
    var isNumbered: Bool { url.lastPathComponent.first?.isNumber == true }
}

/// A pack folder, looked into the way pack authors actually name things: ignoring case, and
/// ignoring which Unicode normalisation an archive happened to store a name in.
struct PackDirectory: Sendable {

    enum Match: Sendable, Equatable {
        case notFound
        case found(PackFile)
        case ambiguous([PackFile])
    }

    let url: URL
    /// Visible regular files at the top level, in Finder order.
    let files: [PackFile]
    private let filesByKey: [String: PackFile]
    /// Files by lower-cased stem, in Finder order, for a name whose extension is wrong.
    private let filesByStem: [String: [PackFile]]

    /// Nil when the folder cannot be listed.
    init?(url: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        self.url = url
        files = contents
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { PackFile(url: $0, name: $0.lastPathComponent) }

        var byKey: [String: PackFile] = [:]
        var byStem: [String: [PackFile]] = [:]
        for file in files {
            if byKey[Self.key(file.name)] == nil { byKey[Self.key(file.name)] = file }
            byStem[Self.key(file.stem), default: []].append(file)
        }
        filesByKey = byKey
        filesByStem = byStem
    }

    static func key(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.lowercased()
    }

    // MARK: - Lookup

    /// The file a pack names. Tried as a top-level name, then as a relative path, then by its
    /// last path component, since most packs that write `stills/001.png` ship it flat.
    ///
    /// A name whose extension is wrong still finds its file when one of the same kind sits
    /// there under the same stem: `icon="icon.png"` with an `icon.jpg` in the folder is the
    /// same picture saved by a different tool, not a missing icon.
    func file(named name: String) -> PackFile? {
        guard let name = name.trimmedOrNil else { return nil }
        if let hit = lookup(name) { return hit }

        let components = name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).map(String.init)
        guard components.count > 1 else { return nil }

        if !components.contains(".."), !components.contains(".") {
            let candidate = components.reduce(url) { $0.appendingPathComponent($1) }
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                return PackFile(url: candidate, name: components.joined(separator: "/"))
            }
        }
        return components.last.flatMap(lookup)
    }

    /// A top-level file by exact name, else by stem among files of the same kind.
    private func lookup(_ name: String) -> PackFile? {
        if let hit = filesByKey[Self.key(name)] { return hit }

        let stem = (name as NSString).deletingPathExtension
        let fileExtension = (name as NSString).pathExtension.lowercased()
        guard !stem.isEmpty, !fileExtension.isEmpty, let kind = Self.kind(of: fileExtension) else { return nil }
        return filesByStem[Self.key(stem)]?.first { kind.contains($0.fileExtension) }
    }

    /// The family an extension belongs to, so a stem lookup never hands a text file to
    /// something asking for audio.
    private static func kind(of fileExtension: String) -> Set<String>? {
        for family in [PackFormat.Files.imageExtensions, PackFormat.Files.audioExtensions, PackFormat.Files.videoExtensions]
        where family.contains(fileExtension) {
            return Set(family)
        }
        return nil
    }

    /// `stem.<extension>` for the first of `extensions` that exists.
    func file(stem: String, extensions: [String]) -> PackFile? {
        files(stem: stem, extensions: extensions).first
    }

    /// Every `stem.<extension>` that exists, in the order of `extensions`.
    func files(stem: String, extensions: [String]) -> [PackFile] {
        extensions.compactMap { filesByKey[Self.key("\(stem).\($0)")] }
    }

    /// Top-level files with any of `extensions`, in Finder order.
    func files(extensions: [String]) -> [PackFile] {
        let wanted = Set(extensions)
        return files.filter { wanted.contains($0.fileExtension) }
    }

    // MARK: - Pack Structure

    var packInfoFile: PackFile? {
        PackFormat.Files.packInfo.lazy.compactMap { filesByKey[$0] }.first
    }

    /// Text files that could be line entries: `.txt` or `.ini`, but not the pack info and not an
    /// `_`-prefixed note. When an entry exists under both extensions, the `.txt` one is it.
    var entryCandidates: [PackFile] {
        let packInfoKeys = Set(PackFormat.Files.packInfo)
        let candidates = files.filter {
            PackFormat.Files.entryExtensions.contains($0.fileExtension)
                && !$0.name.hasPrefix("_")
                && !packInfoKeys.contains(Self.key($0.name))
        }
        let textStems = Set(candidates.filter { $0.fileExtension == "txt" }.map { Self.key($0.stem) })
        return candidates.filter { $0.fileExtension == "txt" || !textStems.contains(Self.key($0.stem)) }
    }

    /// How many top-level files there are of each extension, lower-cased; `""` for none.
    var fileTypeCounts: [String: Int] {
        files.reduce(into: [:]) { counts, file in counts[file.fileExtension, default: 0] += 1 }
    }

    /// How many candidates start with a number, the way line entries are named.
    var numberedEntryCount: Int {
        entryCandidates.filter(\.isNumbered).count
    }

    /// How many candidates are probably line entries: numbered, or with a recording of the
    /// same name beside them, the way a pack written without numbers still pairs its files.
    var likelyEntryCount: Int {
        entryCandidates.filter { $0.isNumbered || hasRecording(beside: $0) }.count
    }

    /// True when an audio file shares `file`'s stem.
    func hasRecording(beside file: PackFile) -> Bool {
        self.file(stem: file.stem, extensions: PackFormat.Files.audioExtensions) != nil
    }

    /// The icon by convention, `icon.png` or `cover.jpg`, when the pack info names none, or
    /// else any unnumbered image whose name says icon or cover, such as `scene_icon.png`.
    var conventionalIcon: PackFile? {
        if let exact = PackFormat.Files.iconStems.lazy
            .compactMap({ file(stem: $0, extensions: PackFormat.Files.imageExtensions) })
            .first {
            return exact
        }
        return files(extensions: PackFormat.Files.imageExtensions).first { image in
            !image.isNumbered && PackFormat.Files.iconStems.contains { Self.key(image.stem).contains($0) }
        }
    }

    /// The scene video: the file named like one, or else the only unnumbered video there is.
    ///
    /// An unnamed file only counts when its extension cannot also be audio: `.ogg` holds a
    /// Theora scene as often as a Vorbis backing track, so it has to be named to be the video.
    var sceneVideo: Match {
        if let named = named(stems: PackFormat.Files.sceneVideoStems, extensions: PackFormat.Files.videoExtensions) {
            return .found(named)
        }
        let audioExtensions = Set(PackFormat.Files.audioExtensions)
        return sole(files(extensions: PackFormat.Files.videoExtensions).filter {
            !$0.isNumbered && !audioExtensions.contains($0.fileExtension)
        })
    }

    /// The backing track: the file named like one, or else the only unnumbered audio file
    /// that no line claims and that is not named like the scene video.
    func backingTrack(claimedNames: Set<String>) -> Match {
        if let named = named(stems: PackFormat.Files.backingTrackStems, extensions: PackFormat.Files.audioExtensions) {
            return .found(named)
        }
        let videoStems = Set(PackFormat.Files.sceneVideoStems)
        let unclaimed = files(extensions: PackFormat.Files.audioExtensions).filter {
            !$0.isNumbered
                && !claimedNames.contains(Self.key($0.name))
                && !videoStems.contains(Self.key($0.stem))
        }
        return sole(unclaimed)
    }

    private func named(stems: [String], extensions: [String]) -> PackFile? {
        stems.lazy.compactMap { file(stem: $0, extensions: extensions) }.first
    }

    private func sole(_ candidates: [PackFile]) -> Match {
        switch candidates.count {
        case 0: .notFound
        case 1: .found(candidates[0])
        default: .ambiguous(candidates)
        }
    }
}
