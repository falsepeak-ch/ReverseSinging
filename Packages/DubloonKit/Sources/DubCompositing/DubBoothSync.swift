//
//  DubBoothSync.swift
//  DubCompositing
//
//  When booth footage lands, relative to the take and to the export
//

import Foundation

// MARK: - Take Clock

/// Decides what happens to each camera frame while a take is being filmed.
///
/// The take's sample zero is the instant the microphone opens (the anchor). The camera keeps
/// its own clock and delivers frames every 1/30 s or so, so no frame lands on the anchor
/// exactly, and a camera that was switched on a moment ago may deliver its first frame late.
/// The rules:
///
/// - A frame from just before the anchor is held on to. If it is the closest the camera came
///   to sample zero, it is written *at* the anchor, so the clip starts with a picture rather
///   than with a gap.
/// - If the camera had nothing before the anchor (it was still warming up), its first frame
///   is moved back to the anchor and holds until the second. The face is a few frames stale
///   at the very start, rather than missing.
/// - Every later frame keeps its own timestamp. That is what keeps lips on the voice.
/// - A frame at or past the end of the line ends the take.
///
/// Pure arithmetic on seconds, so it can be checked without a camera.
public struct DubBoothTakeClock: Equatable, Sendable {

    public enum Step: Equatable, Sendable {
        /// Before the take, and too early to stand in for its first frame.
        case drop
        /// Just before the anchor: keep it, it may be the take's first picture.
        case stash
        /// Write this frame at `at`. When `stashFirst` is set, write the stashed frame at
        /// the anchor before it.
        case write(at: Double, stashFirst: Bool)
        /// The line is over.
        case end
    }

    /// How far before the anchor a frame may be and still stand in for sample zero. A little
    /// over two frames at 30 fps: anything older is the countdown, not the take.
    public static let standInTolerance: Double = 0.075

    public let anchor: Double
    /// The line's length. Zero means open-ended.
    public let duration: Double

    public private(set) var hasStash = false
    public private(set) var hasWritten = false

    public init(anchor: Double, duration: Double) {
        self.anchor = anchor
        self.duration = max(0, duration)
    }

    public mutating func step(forFrameAt time: Double) -> Step {
        if time < anchor {
            guard !hasWritten else { return .drop }
            if anchor - time <= Self.standInTolerance {
                hasStash = true
                return .stash
            }
            return .drop
        }

        if duration > 0, time - anchor >= duration { return .end }

        guard !hasWritten else { return .write(at: time, stashFirst: false) }
        hasWritten = true

        // Exactly on the anchor needs no stand-in.
        if time == anchor {
            hasStash = false
            return .write(at: time, stashFirst: false)
        }
        if hasStash {
            hasStash = false
            return .write(at: time, stashFirst: true)
        }
        // A late camera: its first frame is moved back to sample zero.
        return .write(at: anchor, stashFirst: false)
    }
}

// MARK: - Export Placement

/// Where a line's booth clip goes in an export, and which part of it.
///
/// A clip's zero is its take's zero, which is the line's start on the scene timeline. A cut
/// can start or end inside a line (the whole scene ends mid-line; a session reel drops the
/// silence between lines), so the clip is trimmed to the overlap and laid at the same offset
/// the voice is.
public enum DubBoothPlacement {

    public struct Placement: Equatable, Sendable {
        /// Where in the clip to start reading.
        public let clipStart: Double
        /// How much of it to use.
        public let duration: Double
        /// Where it lands in the exported file.
        public let outputStart: Double
    }

    /// - Parameters:
    ///   - lineStart, lineEnd: the line, in scene time.
    ///   - segmentStart, segmentEnd: the stretch of scene time this part of the export is.
    ///   - segmentOutputStart: where that stretch begins in the exported file.
    ///   - clipDuration: how long the clip on disk really is. A take the performer cut
    ///     short leaves a shorter clip, and asking for more than it has would fail the export.
    public static func place(
        lineStart: Double,
        lineEnd: Double,
        segmentStart: Double,
        segmentEnd: Double,
        segmentOutputStart: Double,
        clipDuration: Double
    ) -> Placement? {
        let overlapStart = max(lineStart, segmentStart)
        let overlapEnd = min(lineEnd, segmentEnd)
        guard overlapEnd > overlapStart else { return nil }

        let clipStart = overlapStart - lineStart
        let duration = min(overlapEnd - overlapStart, clipDuration - clipStart)
        guard duration > 0 else { return nil }

        return Placement(
            clipStart: clipStart,
            duration: duration,
            outputStart: segmentOutputStart + (overlapStart - segmentStart)
        )
    }
}
