//
//  DubPackIssue.swift
//  DubPackKit
//

/// Something a pack could not provide, on the way to importing anyway.
///
/// A pack comes in whole whenever it can and in part when it cannot: an entry that will not read
/// is dropped, a missing still borrows its neighbour's, a video that will not convert leaves the
/// stills. Each of those is recorded as an issue, because a pack that arrives with four of its
/// sixty lines looks, to the person who made it, exactly like a broken app.
///
/// File names are names inside the pack. Nothing here carries a caption or anything else the
/// pack says.
public enum DubPackIssue: Sendable, Hashable {
    /// An entry that could not become a line.
    case droppedLine(file: String, reason: DroppedLineReason)
    /// Nothing in the pack looks like a line entry. Carries how many files there are of each
    /// extension, which shows at a glance what the pack uses instead.
    case noLineEntries(fileTypes: [String: Int])
    /// An entry with more start times than the one it is performed at.
    case extraTimestampsIgnored(file: String, count: Int)
    /// An entry with no still, shown over `substitute` instead.
    case missingStill(file: String, substitute: String?)
    /// The pack info names an icon that is not in the pack.
    case missingIcon(file: String)
    /// No pack info file under any accepted name. The pack is titled after its folder.
    /// Carries the text files that were there, which is how a new alias gets noticed.
    case missingPackInfo(otherTextFiles: [String])
    /// A pack info file in no encoding the reader knows.
    case unreadablePackInfo(file: String)
    /// Several audio files that could each be the backing track, none named as one.
    case ambiguousBackingTrack(candidates: [String])
    /// A backing track AVFoundation cannot decode. The scene plays in silence.
    case unplayableBackingTrack(file: String)
    /// Several videos that could each be the scene, none named as one.
    case ambiguousSceneVideo(candidates: [String])
    /// A scene video with no track AVFoundation can decode. The scene shows its stills.
    case unplayableSceneVideo(file: String)
    /// A Theora scene that could not be converted. The scene shows its stills.
    case videoConversionFailed(file: String, failure: VideoConversionFailure)
    /// A zip whose index was missing or unreadable, recovered entry by entry from the front.
    /// Carries the file the end of the archive cut through, if any, whether that partial file was
    /// kept, and how many entries failed their checksum and were left out.
    case archiveRecovered(truncatedEntry: String?, partialKept: Bool, damagedEntries: Int)
    /// Archive entries refused for pointing outside the pack, such as `../evil.txt`.
    case unsafeArchiveEntriesSkipped(count: Int)
}

/// Why an entry could not become a line.
public enum DroppedLineReason: String, Sendable, Hashable, CaseIterable {
    /// The entry is not text in any encoding the reader knows.
    case unreadableText = "unreadable_file"
    /// No start time, so there is no moment to play the line at.
    case missingTimestamp = "no_timestamp"
    /// A start time that is not a number of seconds.
    case invalidTimestamp = "invalid_timestamp"
    /// No audio beside the entry under any name or extension the reader knows.
    case missingAudio = "missing_audio"
    /// Audio is there, but AVFoundation cannot decode it. Ogg Vorbis, most often.
    case unplayableAudio = "unplayable_audio"
}
