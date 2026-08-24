//
//  DubPack.swift
//  ReverseSinging
//
//  Data models for an imported dub pack
//

import Foundation

/// A single spoken line within a dub pack.
///
/// File references are stored as names, not URLs: the app's Documents container path
/// changes across reinstalls and device restores, so an absolute URL persisted today
/// may not resolve tomorrow. Resolve against the pack directory at use time.
struct DubLine: Identifiable, Codable, Hashable {
    let id: UUID
    let index: Int              // 1, parsed from "001_Dobby"
    let slug: String            // "001_Dobby"
    let character: String       // "Mr Dursley" (from dub_characters)
    let caption: String
    let imageFile: String       // "001_Dobby.jpg"
    let referenceAudioFile: String  // "001_Dobby.wav"
    let startTime: TimeInterval // dub_timestamps[0] — offset on the master timeline
    let duration: TimeInterval  // measured from the reference wav at import

    init(
        id: UUID = UUID(),
        index: Int,
        slug: String,
        character: String,
        caption: String,
        imageFile: String,
        referenceAudioFile: String,
        startTime: TimeInterval,
        duration: TimeInterval
    ) {
        self.id = id
        self.index = index
        self.slug = slug
        self.character = character
        self.caption = caption
        self.imageFile = imageFile
        self.referenceAudioFile = referenceAudioFile
        self.startTime = startTime
        self.duration = duration
    }

    var endTime: TimeInterval { startTime + duration }

    var formattedStartTime: String {
        let minutes = Int(startTime) / 60
        let seconds = Int(startTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// A dub pack: a scene broken into lines, with a dialogue-free backing track.
struct DubPack: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let authors: [String]
    let iconFile: String            // "001_Dobby.jpg"
    let backingTrackFile: String?   // "_backing_track.mp3"
    /// "dub_video.mp4", when the pack ships a video AVFoundation can actually play.
    /// Optional so manifests written before video support still decode — those packs
    /// fall back to their per-line stills.
    let videoFile: String?
    let folderName: String          // directory name inside DubPacks/
    let lines: [DubLine]
    let duration: TimeInterval
    let importedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        authors: [String],
        iconFile: String,
        backingTrackFile: String?,
        videoFile: String? = nil,
        folderName: String,
        lines: [DubLine],
        duration: TimeInterval,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.iconFile = iconFile
        self.backingTrackFile = backingTrackFile
        self.videoFile = videoFile
        self.folderName = folderName
        self.lines = lines
        self.duration = duration
        self.importedAt = importedAt
    }

    // MARK: - Path Resolution

    var directoryURL: URL {
        AudioFileManager.shared.dubPacksDirectory().appendingPathComponent(folderName, isDirectory: true)
    }

    func url(forAsset name: String) -> URL {
        directoryURL.appendingPathComponent(name)
    }

    var iconURL: URL { url(forAsset: iconFile) }

    var backingTrackURL: URL? {
        backingTrackFile.map { url(forAsset: $0) }
    }

    var videoURL: URL? {
        videoFile.map { url(forAsset: $0) }
    }

    func imageURL(for line: DubLine) -> URL { url(forAsset: line.imageFile) }

    func referenceAudioURL(for line: DubLine) -> URL { url(forAsset: line.referenceAudioFile) }

    /// Where the user's own take for a line lives (whether or not it has been recorded yet).
    func takeURL(for line: DubLine) -> URL {
        AudioFileManager.shared.dubTakesDirectory(packID: id).appendingPathComponent("\(line.slug).caf")
    }

    // MARK: - Display Helpers

    var authorsDescription: String {
        authors.isEmpty ? Strings.Dub.unknownAuthor : authors.joined(separator: ", ")
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// The distinct characters in the scene, in order of first appearance.
    var characters: [String] {
        var seen = Set<String>()
        return lines.compactMap { seen.insert($0.character).inserted ? $0.character : nil }
    }

    /// The line playing at `time`, or the most recent one if we're in a gap between lines.
    func line(at time: TimeInterval) -> DubLine? {
        guard let first = lines.first, time >= first.startTime else { return lines.first }

        var low = 0
        var high = lines.count - 1
        var match = 0

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].startTime <= time {
                match = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return lines[match]
    }
}
