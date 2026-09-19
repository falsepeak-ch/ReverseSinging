//
//  DubBoothComposer.swift
//  ReverseSinging
//
//  Cuts an export, and composites the booth into it
//

import AVFoundation
import CoreGraphics
import DubCompositing

// MARK: - Cut

/// Which stretch of the film an export covers.
nonisolated enum DubCut: Equatable, Sendable {
    /// The finished dub, top to tail. What Export has always produced.
    case fullScene
    /// One line on its own, by slug.
    case line(String)
    /// Every dubbed line, back to back, with the silence between them dropped.
    case sessionReel

    var analyticsName: String {
        switch self {
        case .fullScene: return "full_scene"
        case .line: return "line"
        case .sessionReel: return "session_reel"
        }
    }
}

/// One stretch of scene time that ends up in an export, in output order.
nonisolated struct DubExportSegment: Equatable, Sendable {
    let start: TimeInterval
    let duration: TimeInterval
    /// The line this segment is exactly, when it is one. Nil for the whole scene.
    let slug: String?

    var end: TimeInterval { start + duration }
}

// MARK: - Cut Planner

/// Turns a cut into the segments of scene time it is made of.
///
/// Kept apart from AVFoundation so the three cuts can be checked as arithmetic. A session reel
/// that silently dropped a line, or a single-line cut off by the length of its own run-up, is
/// not something you would notice in a rendered file.
nonisolated enum DubCutPlanner {

    static func segments(for cut: DubCut, pack: DubPack, recordedSlugs: Set<String>) -> [DubExportSegment] {
        switch cut {
        case .fullScene:
            guard pack.duration > 0 else { return [] }
            return [DubExportSegment(start: 0, duration: pack.duration, slug: nil)]

        case .line(let slug):
            guard let line = pack.lines.first(where: { $0.slug == slug }), line.duration > 0 else {
                return []
            }
            return [segment(for: line, in: pack)]

        case .sessionReel:
            // Recording order is scene order; a reel that jumped about would read as broken
            // rather than as a highlight.
            return pack.lines
                .filter { recordedSlugs.contains($0.slug) && $0.duration > 0 }
                .map { segment(for: $0, in: pack) }
        }
    }

    /// A line's own stretch, clamped to the scene so a manifest whose last line runs past the
    /// end of the film cannot ask for footage that is not there.
    private static func segment(for line: DubLine, in pack: DubPack) -> DubExportSegment {
        let start = max(0, line.startTime)
        let end = pack.duration > 0 ? min(line.endTime, pack.duration) : line.endTime
        return DubExportSegment(start: start, duration: max(0, end - start), slug: line.slug)
    }
}

// MARK: - Composer

/// Builds the composition an export renders from: the cut, and the booth laid into it.
nonisolated struct DubBoothComposer {

    /// What a composed export needs to render.
    struct Composed {
        let composition: AVComposition
        /// Nil when nothing has to be composited, so the caller can remux instead of re-encode.
        let videoComposition: AVVideoComposition?
        let duration: CMTime
    }

    /// Timescale for every range built here. High enough that a line boundary rounds to well
    /// under a frame at any sane frame rate.
    private static let timescale: CMTimeScale = 600

    /// The compositor renders one frame per `frameDuration`, and the encoder pays for every
    /// one of them.
    ///
    /// Taken from the scene rather than fixed, because inventing frames is the most expensive
    /// thing an export can do and the least visible: the public-domain transfers these packs
    /// are cut from run at 24, and rendering them at 30 was a quarter of the encode spent
    /// duplicating pictures nobody asked for. Clamped at both ends so a mis-tagged track
    /// cannot ask for a thousand-frame-per-second render or a slideshow.
    private static func frameDuration(matching frameRate: Float) -> CMTime {
        let rate = frameRate > 0 ? min(max(frameRate.rounded(), 12), 30) : 30
        return CMTime(value: 1, timescale: CMTimeScale(rate))
    }

    /// - Parameters:
    ///   - includesBooth: whether the performer's own footage goes in at all. A vertical frame
    ///     with this off is still composited: it is reshaped to 9:16 and carries the waveform
    ///     strip, which is a different file from the untouched remux `off` produces.
    ///   - sceneVideo: the pack's own film, or the rendered slideshow standing in for it.
    ///   - audio: the finished mix, already cut to `segments` and running the length of the
    ///     export. See `DubAudioCut`.
    ///   - boothClips: booth footage by line slug. Lines with no entry simply have none.
    ///   - waveVideo: the rendered waveform strip, when the frame carries one. Laid in as a
    ///     third track rather than drawn over the top; see `DubWaveOverlay`.
    static func compose(
        pack: DubPack,
        segments: [DubExportSegment],
        frame: DubBoothFrame,
        includesBooth: Bool = true,
        sceneVideo: URL,
        audio: URL,
        boothClips: [String: URL],
        waveVideo: URL? = nil
    ) async throws -> Composed {
        guard !segments.isEmpty else { throw DubExportError.nothingRecorded }

        let composition = AVMutableComposition()

        let sceneAsset = AVURLAsset(url: sceneVideo)
        let audioAsset = AVURLAsset(url: audio)

        guard let sceneSource = try await sceneAsset.loadTracks(withMediaType: .video).first else {
            throw DubExportError.renderSetupFailed
        }
        let audioSource = try await audioAsset.loadTracks(withMediaType: .audio).first

        guard let sceneTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw DubExportError.renderSetupFailed }

        let audioTrack = audioSource == nil ? nil : composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        // Only opened when the frame actually shows a booth, so an `off` export builds the
        // same single-track composition it always did.
        var boothTrack: AVMutableCompositionTrack?
        var boothSource: AVAssetTrack?
        var boothDisplaySize = CGSize(width: 720, height: 1280)
        var boothRanges: [CMTimeRange] = []

        let sceneDuration = try await sceneAsset.load(.duration)
        let sceneFrameRate = try? await sceneSource.load(.nominalFrameRate)
        let audioDuration = try await audioAsset.load(.duration)
        let sceneDisplaySize = try await displaySize(of: sceneSource)

        var cursor = CMTime.zero

        for segment in segments {
            let start = time(segment.start)
            let duration = time(segment.duration)
            guard duration.seconds > 0 else { continue }

            // The film can be shorter than the manifest claims; asking for more than it has
            // throws rather than padding, and one bad timestamp would fail the whole export.
            let videoRange = clamp(CMTimeRange(start: start, duration: duration), to: sceneDuration)
            if videoRange.duration.seconds > 0 {
                try sceneTrack.insertTimeRange(videoRange, of: sceneSource, at: cursor)
            }

            if frame.needsCompositing && includesBooth {
                for line in pack.lines {
                    guard let clipURL = boothClips[line.slug] else { continue }

                    // The part of this line that falls inside this segment. For a single-line
                    // or session-reel cut that is the whole line; for the full scene it is
                    // every line in turn.
                    let overlapStart = max(line.startTime, segment.start)
                    let overlapEnd = min(line.endTime, segment.end)
                    guard overlapEnd > overlapStart else { continue }

                    let clipAsset = AVURLAsset(url: clipURL)
                    guard let clipSource = try await clipAsset.loadTracks(withMediaType: .video).first else {
                        continue
                    }
                    let clipDuration = try await clipAsset.load(.duration)

                    if boothTrack == nil {
                        boothTrack = composition.addMutableTrack(
                            withMediaType: .video,
                            preferredTrackID: kCMPersistentTrackID_Invalid
                        )
                        boothSource = clipSource
                        boothDisplaySize = try await displaySize(of: clipSource)
                    }
                    guard let boothTrack else { continue }

                    // Where in the clip the overlap starts. A clip is written from the
                    // microphone's own anchor, so its zero is the line's zero.
                    let clipRange = clamp(
                        CMTimeRange(
                            start: time(overlapStart - line.startTime),
                            duration: time(overlapEnd - overlapStart)
                        ),
                        to: clipDuration
                    )
                    guard clipRange.duration.seconds > 0 else { continue }

                    let at = CMTimeAdd(cursor, time(overlapStart - segment.start))
                    try boothTrack.insertTimeRange(clipRange, of: clipSource, at: at)
                    boothRanges.append(CMTimeRange(start: at, duration: clipRange.duration))
                }
            }

            cursor = CMTimeAdd(cursor, duration)
        }

        guard cursor.seconds > 0 else { throw DubExportError.nothingRecorded }

        // The audio is already the cut, in output time, so it is laid in once from the top.
        // Clamped to the picture: the mix runs past the scene when a take does.
        if let audioTrack, let audioSource {
            let audioRange = clamp(CMTimeRange(start: .zero, duration: cursor), to: audioDuration)
            if audioRange.duration.seconds > 0 {
                try audioTrack.insertTimeRange(audioRange, of: audioSource, at: .zero)
            }
        }

        // The strip runs the length of the export, so it is laid in once rather than per
        // segment. Its clip is rendered to the output's own duration, which is `cursor`.
        var waveTrack: AVMutableCompositionTrack?
        if let waveVideo, frame.isVertical {
            let waveAsset = AVURLAsset(url: waveVideo)
            if let waveSource = try? await waveAsset.loadTracks(withMediaType: .video).first,
               let track = composition.addMutableTrack(
                   withMediaType: .video,
                   preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                let waveDuration = try await waveAsset.load(.duration)
                let range = clamp(CMTimeRange(start: .zero, duration: cursor), to: waveDuration)
                if range.duration.seconds > 0 {
                    try track.insertTimeRange(range, of: waveSource, at: .zero)
                    waveTrack = track
                }
            }
        }

        let hasBooth = boothTrack != nil && boothSource != nil && !boothRanges.isEmpty

        // Nothing to lay over the picture, and no reshaping asked for: hand back a plain
        // composition and let the caller remux it rather than paying for a re-encode nobody
        // asked for. A vertical frame always earns its re-encode, booth or no booth, because
        // the 9:16 canvas and the waveform strip are the point of it.
        guard frame.needsCompositing, hasBooth || frame.isVertical else {
            return Composed(composition: composition, videoComposition: nil, duration: cursor)
        }

        let layout = DubBoothLayout.make(
            frame: frame,
            sceneDisplaySize: sceneDisplaySize,
            boothDisplaySize: boothDisplaySize
        )

        let videoComposition = try videoComposition(
            layout: layout,
            sceneTrack: sceneTrack,
            sceneDisplaySize: sceneDisplaySize,
            boothTrack: hasBooth ? boothTrack : nil,
            boothDisplaySize: boothDisplaySize,
            boothRanges: hasBooth ? boothRanges : [],
            duration: cursor,
            frameRate: sceneFrameRate ?? 0,
            waveTrack: waveTrack
        )

        return Composed(composition: composition, videoComposition: videoComposition, duration: cursor)
    }

    // MARK: - Video Composition

    /// One instruction per stretch where the booth is either present or absent.
    ///
    /// A single instruction spanning the whole film would place the booth over the gaps
    /// between lines too, where its track has nothing to show. Splitting on the same
    /// boundaries is also what lets the scene move: it takes `sceneRect` where the booth is
    /// beside it and `sceneRectAlone` where it isn't, so the band the booth would have had is
    /// given back rather than left black.
    private static func videoComposition(
        layout: DubBoothLayout,
        sceneTrack: AVMutableCompositionTrack,
        sceneDisplaySize: CGSize,
        boothTrack: AVMutableCompositionTrack?,
        boothDisplaySize: CGSize,
        boothRanges: [CMTimeRange],
        duration: CMTime,
        frameRate: Float,
        waveTrack: AVMutableCompositionTrack?
    ) throws -> AVVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.renderSize = layout.renderSize
        composition.frameDuration = Self.frameDuration(matching: frameRate)

        let withBooth = DubBoothLayout.fillTransform(
            displaySize: sceneDisplaySize,
            into: layout.sceneRect
        )
        let alone = DubBoothLayout.fillTransform(
            displaySize: sceneDisplaySize,
            into: layout.sceneRectAlone
        )
        let boothTransform = layout.boothRect.map {
            DubBoothLayout.fillTransform(displaySize: boothDisplaySize, into: $0)
        }
        // The strip clip is rendered at exactly the size of the band it goes in, so this is a
        // translation. Kept going through `fillTransform` anyway, so there is one answer in
        // the codebase to "where does a source land in a rect".
        let waveTransform = layout.waveRect.map {
            DubBoothLayout.fillTransform(displaySize: $0.size, into: $0)
        }

        var instructions: [AVMutableVideoCompositionInstruction] = []

        for range in coverage(of: boothRanges, within: duration) {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = range.range

            // Front-most of all, over both pictures: the booth is portrait and spills out of
            // its band, and the strip is what stops that spill reaching the bottom edge.
            var wave: [AVMutableVideoCompositionLayerInstruction] = []
            if let waveTrack, let waveTransform {
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: waveTrack)
                layer.setTransform(waveTransform, at: .zero)
                wave = [layer]
            }

            let scene = AVMutableVideoCompositionLayerInstruction(assetTrack: sceneTrack)

            guard range.hasBooth, let boothTrack, let boothTransform else {
                scene.setTransform(alone, at: .zero)
                instruction.layerInstructions = wave + [scene]
                instructions.append(instruction)
                continue
            }

            scene.setTransform(withBooth, at: .zero)

            let booth = AVMutableVideoCompositionLayerInstruction(assetTrack: boothTrack)
            booth.setTransform(boothTransform, at: .zero)

            // Front-most first. Whichever layer is listed first hides the other's overflow,
            // which is what `DubBoothLayout` arranges its rects around.
            let pictures: [AVMutableVideoCompositionLayerInstruction] =
                layout.boothIsOnTop ? [booth, scene] : [scene, booth]
            instruction.layerInstructions = wave + pictures
            instructions.append(instruction)
        }

        composition.instructions = instructions
        return composition
    }

    /// Splits `duration` into consecutive ranges, each marked with whether the booth is in it.
    static func coverage(
        of boothRanges: [CMTimeRange],
        within duration: CMTime
    ) -> [(range: CMTimeRange, hasBooth: Bool)] {
        let merged = merge(boothRanges)
        var result: [(CMTimeRange, Bool)] = []
        var cursor = CMTime.zero

        for range in merged {
            let start = CMTimeMaximum(range.start, .zero)
            let end = CMTimeMinimum(CMTimeAdd(range.start, range.duration), duration)
            guard CMTimeCompare(end, start) > 0 else { continue }

            if CMTimeCompare(start, cursor) > 0 {
                result.append((CMTimeRange(start: cursor, end: start), false))
            }
            result.append((CMTimeRange(start: start, end: end), true))
            cursor = end
        }

        if CMTimeCompare(cursor, duration) < 0 {
            result.append((CMTimeRange(start: cursor, end: duration), false))
        }

        // A composition with no instruction at all renders nothing.
        return result.isEmpty ? [(CMTimeRange(start: .zero, duration: duration), false)] : result
    }

    /// Overlapping booth ranges would produce overlapping instructions, which AVFoundation
    /// rejects outright. Lines can overlap in a manifest, so this is not hypothetical.
    private static func merge(_ ranges: [CMTimeRange]) -> [CMTimeRange] {
        let sorted = ranges.sorted { CMTimeCompare($0.start, $1.start) < 0 }
        var merged: [CMTimeRange] = []

        for range in sorted {
            guard let last = merged.last else {
                merged.append(range)
                continue
            }
            let lastEnd = CMTimeAdd(last.start, last.duration)
            if CMTimeCompare(range.start, lastEnd) <= 0 {
                let end = CMTimeMaximum(lastEnd, CMTimeAdd(range.start, range.duration))
                merged[merged.count - 1] = CMTimeRange(start: last.start, end: end)
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    // MARK: - Helpers

    /// The shape a pack's picture comes out at, or nil for a pack with no video of its own.
    ///
    /// The export sheet needs this before anything is rendered, to say what shape the file
    /// will be and to lay its diagram out at that shape. Read here rather than in the view so
    /// there is one answer to the question, and it is the one the render uses.
    static func sceneDisplaySize(of pack: DubPack) async -> CGSize? {
        guard let url = pack.videoURL else { return nil }
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await displaySize(of: track),
              size.width > 0, size.height > 0 else { return nil }
        return size
    }

    /// A track's size as it is meant to be *seen*, with its preferred transform applied.
    private static func displaySize(of track: AVAssetTrack) async throws -> CGSize {
        let natural = try await track.load(.naturalSize)
        let preferred = try await track.load(.preferredTransform)
        let rect = CGRect(origin: .zero, size: natural).applying(preferred)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    private static func time(_ seconds: TimeInterval) -> CMTime {
        CMTime(seconds: max(0, seconds), preferredTimescale: timescale)
    }

    private static func clamp(_ range: CMTimeRange, to limit: CMTime) -> CMTimeRange {
        let start = CMTimeMinimum(range.start, limit)
        let end = CMTimeMinimum(CMTimeAdd(range.start, range.duration), limit)
        guard CMTimeCompare(end, start) > 0 else {
            return CMTimeRange(start: start, duration: .zero)
        }
        return CMTimeRange(start: start, end: end)
    }
}
