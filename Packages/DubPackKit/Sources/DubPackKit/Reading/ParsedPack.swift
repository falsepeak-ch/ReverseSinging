//
//  ParsedPack.swift
//  DubPackKit
//

public import Foundation

/// A dub pack as read from its folder: what it is called, what it plays, and its lines.
///
/// File references are names relative to the pack folder, never URLs, so the value stays
/// correct wherever the folder is moved to.
public struct ParsedPack: Sendable, Hashable {
    public let title: String
    public let authors: [String]
    /// The picture that stands for the pack. Nil only when the pack has no image at all.
    public let iconFile: String?
    /// A dialogue-free mix to perform over, when the pack has one AVFoundation can play.
    public let backingTrackFile: String?
    /// The scene video, when the pack has one AVFoundation can play.
    public let videoFile: String?
    /// Ordered by start time.
    public let lines: [ParsedLine]
    /// The backing track's length, else the video's, else the end of the last line.
    public let duration: TimeInterval
    public let provenance: PackProvenance

    public init(
        title: String,
        authors: [String],
        iconFile: String?,
        backingTrackFile: String?,
        videoFile: String?,
        lines: [ParsedLine],
        duration: TimeInterval,
        provenance: PackProvenance
    ) {
        self.title = title
        self.authors = authors
        self.iconFile = iconFile
        self.backingTrackFile = backingTrackFile
        self.videoFile = videoFile
        self.lines = lines
        self.duration = duration
        self.provenance = provenance
    }
}

/// One spoken line of a pack.
public struct ParsedLine: Sendable, Hashable {
    /// The number the entry's name starts with (`018_Mr_Dursley` is 18), else its position.
    public let index: Int
    /// The entry's file name without its extension, unique within the pack.
    public let slug: String
    public let character: String
    public let caption: String
    /// The still shown while the line plays. A line whose own still is missing borrows the
    /// one before it, so this is nil only when the pack has no image at all.
    public let imageFile: String?
    /// The original performance, which the user's take is recorded against.
    public let referenceAudioFile: String
    /// Where the line starts on the scene's timeline, in seconds.
    public let startTime: TimeInterval
    /// The reference audio's length, in seconds.
    public let duration: TimeInterval

    public var endTime: TimeInterval { startTime + duration }

    public init(
        index: Int,
        slug: String,
        character: String,
        caption: String,
        imageFile: String?,
        referenceAudioFile: String,
        startTime: TimeInterval,
        duration: TimeInterval
    ) {
        self.index = index
        self.slug = slug
        self.character = character
        self.caption = caption
        self.imageFile = imageFile
        self.referenceAudioFile = referenceAudioFile
        self.startTime = startTime
        self.duration = duration
    }
}

/// Where a pack's scene comes from and on what terms, as its pack info states it.
///
/// For a scene cut from someone else's work under a licence such as CC BY, showing this is the
/// licence condition being met. All three are nil for the typical pack a user made.
public struct PackProvenance: Sendable, Hashable {
    /// Human-readable origin, e.g. `Sprite Fright (2021), Blender Studio`.
    public let source: String?
    public let sourceURL: String?
    /// The terms, e.g. `CC BY 4.0 - https://creativecommons.org/licenses/by/4.0/`.
    public let rights: String?

    public static let unknown = PackProvenance(source: nil, sourceURL: nil, rights: nil)

    public init(source: String?, sourceURL: String?, rights: String?) {
        self.source = source
        self.sourceURL = sourceURL
        self.rights = rights
    }

    init(fields: PackFields) {
        self.init(
            source: fields.string(PackFormat.Keys.source),
            sourceURL: fields.string(PackFormat.Keys.sourceURL),
            rights: fields.string(PackFormat.Keys.rights)
        )
    }
}
