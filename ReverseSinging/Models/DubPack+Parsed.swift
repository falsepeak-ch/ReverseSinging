//
//  DubPack+Parsed.swift
//  ReverseSinging
//
//  Turning what DubPackKit read into the app's own pack model
//

import DubPackKit
import Foundation
import DubAudio

nonisolated extension DubPack {

    /// The app's pack for one DubPackKit read, with every line's speech window measured.
    ///
    /// Measuring reads every reference recording in full, which is the expensive part of a
    /// pack and exactly why the result is cached in the manifest: call this off the main actor.
    ///
    /// - Parameters:
    ///   - directory: where the pack's files are right now, which is where the recordings are
    ///     measured from. Its name is the pack's `folderName` unless one is given.
    ///   - folderName: the folder the pack will live in, when it is still being staged
    ///     elsewhere.
    ///   - id: the pack's identity. Pass the previous install's to keep the user's takes.
    init(parsed: ParsedPack, directory: URL, folderName: String? = nil, id: UUID = UUID(), importedAt: Date = Date()) {
        self.init(
            id: id,
            title: parsed.title,
            authors: parsed.authors,
            iconFile: parsed.iconFile ?? "",
            backingTrackFile: parsed.backingTrackFile,
            videoFile: parsed.videoFile,
            folderName: folderName ?? directory.lastPathComponent,
            lines: parsed.lines.map { DubLine(parsed: $0, in: directory) },
            duration: parsed.duration,
            importedAt: importedAt,
            source: parsed.provenance.source,
            sourceURL: parsed.provenance.sourceURL,
            rights: parsed.provenance.rights
        )
    }
}

nonisolated extension DubLine {

    init(parsed: ParsedLine, in directory: URL) {
        let referenceAudio = directory.appendingPathComponent(parsed.referenceAudioFile)

        self.init(
            index: parsed.index,
            slug: parsed.slug,
            character: parsed.character,
            caption: parsed.caption,
            imageFile: parsed.imageFile ?? "",
            referenceAudioFile: parsed.referenceAudioFile,
            startTime: parsed.startTime,
            duration: parsed.duration,
            speech: Self.speechWindow(at: referenceAudio, duration: parsed.duration)
        )
    }

    /// Where the dialogue sits inside a reference chunk.
    ///
    /// Measured once and stored, so playback, export, captions and scoring all read the same
    /// window and cannot disagree about when a line happens. Falls back to the whole chunk for
    /// a reference that is silent or unreadable.
    private static func speechWindow(at url: URL, duration: TimeInterval) -> DubSpeechWindow {
        guard duration > 0,
              let buffer = try? DubAudioLoader.loadVoiceBuffer(from: url, applyFades: false),
              let window = DubSpeechOnset.window(of: buffer) else {
            return DubSpeechWindow(start: 0, end: duration)
        }

        return DubSpeechWindow(
            start: min(max(0, window.start), duration),
            end: min(max(window.start, window.end), duration)
        )
    }
}
