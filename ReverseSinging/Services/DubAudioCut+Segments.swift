//
//  DubAudioCut+Segments.swift
//  ReverseSinging
//
//  The audio of a planned export cut
//

import DubAudio
import Foundation

nonisolated extension DubAudioCut {

    /// The cut's audio for the segments `DubCutPlanner` chose.
    ///
    /// A plan with no segments has nothing recorded in it, and fails the export the way it
    /// always has rather than as a bare cut error.
    static func cut(_ mix: URL, to segments: [DubExportSegment], in directory: URL) throws -> URL {
        guard !segments.isEmpty else { throw DubExportError.nothingRecorded }
        return try cut(mix, to: segments.map { $0.start..<max($0.start, $0.end) }, in: directory)
    }
}
