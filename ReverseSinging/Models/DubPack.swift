//
//  DubPack.swift
//  ReverseSinging
//
//  Data models for an imported dub pack
//

import Foundation

/// The stretch of a reference chunk the character is actually speaking over, in seconds from
/// the chunk's own start.
///
/// Measured once, at import, by `DubSpeechOnset`. Everything that has to agree on *when a
/// line happens* — where a take is dropped in the mix, when its caption appears, what the
/// score is measured against — reads it from here rather than re-deriving it, so those
/// answers cannot drift apart.
nonisolated struct DubSpeechWindow: Codable, Hashable {
    let start: TimeInterval
    let end: TimeInterval

    var duration: TimeInterval { max(0, end - start) }
}

/// A single spoken line within a dub pack.
///
/// File references are stored as names, not URLs: the app's Documents container path
/// changes across reinstalls and device restores, so an absolute URL persisted today
/// may not resolve tomorrow. Resolve against the pack directory at use time.
nonisolated struct DubLine: Identifiable, Codable, Hashable {
    let id: UUID
    let index: Int              // 1, parsed from "001_Dobby"
    let slug: String            // "001_Dobby"
    let character: String       // "Mr Dursley" (from dub_characters)
    let caption: String
    let imageFile: String       // "001_Dobby.jpg"
    let referenceAudioFile: String  // "001_Dobby.wav"
    let startTime: TimeInterval // dub_timestamps[0] — offset on the master timeline
    let duration: TimeInterval  // measured from the reference wav at import

    /// Where the speech sits inside the chunk. Optional so manifests written before speech
    /// windows were measured still decode — those packs fall back to the whole chunk, and
    /// `DubPackLibrary` re-measures them on the next launch.
    let speech: DubSpeechWindow?

    init(
        id: UUID = UUID(),
        index: Int,
        slug: String,
        character: String,
        caption: String,
        imageFile: String,
        referenceAudioFile: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        speech: DubSpeechWindow? = nil
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
        self.speech = speech
    }

    var endTime: TimeInterval { startTime + duration }

    // MARK: - Speech Timing

    /// Silence in front of the dialogue, inside the chunk. Zero for an unmeasured line.
    var speechLead: TimeInterval { min(max(0, speech?.start ?? 0), duration) }

    /// Where the dialogue stops, inside the chunk. The whole chunk for an unmeasured line.
    var speechTail: TimeInterval { min(max(speechLead, speech?.end ?? duration), duration) }

    /// When the character starts speaking on the scene's timeline.
    ///
    /// This — not `startTime` — is the beat a take is aligned to and a caption is shown on.
    var speechStartTime: TimeInterval { startTime + speechLead }

    /// When the character stops speaking on the scene's timeline.
    var speechEndTime: TimeInterval { startTime + speechTail }

    var formattedStartTime: String {
        let minutes = Int(speechStartTime) / 60
        let seconds = Int(speechStartTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// A dub pack: a scene broken into lines, with a dialogue-free backing track.
nonisolated struct DubPack: Identifiable, Codable, Hashable {
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

    /// True once every line knows where its dialogue sits inside its chunk.
    ///
    /// False for a pack imported by a build that predates the measurement, which is the
    /// signal to re-parse it rather than keep serving timings that are a chunk out.
    var hasMeasuredSpeech: Bool { lines.allSatisfy { $0.speech != nil } }

    // MARK: - Caption Timing

    /// How long before the first word a caption goes up. Enough to read the line coming,
    /// not enough to give away a beat that hasn't landed.
    static let captionLead: TimeInterval = 0.3

    /// How long a caption stays up after the last word, so it doesn't blink out on the
    /// closing syllable.
    static let captionHold: TimeInterval = 0.7

    /// The caption to show at `time`, or nil during a gap in the dialogue.
    ///
    /// Deliberately not `line(at:)`. That one answers "which line's picture is this", and it
    /// holds the most recent line forever, from the start of its *chunk* — which begins up to
    /// two seconds before anyone speaks and runs until the next chunk starts, however long the
    /// silence in between. As a subtitle that reads as wrong twice over: the words show up
    /// early, then sit there through the pause that follows.
    ///
    /// A caption instead runs from just before the first word to just after the last, and
    /// nothing is shown in between. Where two characters overlap, the one who spoke most
    /// recently wins — that is who the viewer is listening to.
    ///
    /// Scanned rather than searched: `speechStartTime` is `startTime` plus a per-line lead, so
    /// the lines are not strictly ordered by it, and at ~60 lines the scan costs nothing.
    func captionLine(at time: TimeInterval) -> DubLine? {
        var best: DubLine?

        for line in lines {
            let from = line.speechStartTime - Self.captionLead
            let until = line.speechEndTime + Self.captionHold
            guard time >= from, time < until else { continue }

            if let current = best, current.speechStartTime > line.speechStartTime { continue }
            best = line
        }

        return best
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
