//
//  DubScorer+DubLine.swift
//  ReverseSinging
//
//  Scoring a take against the pack line it replaces
//

import DubScoring
import Foundation

nonisolated extension DubScorer {

    /// Scores the take recorded for `line`, timing its entry against the speech window measured
    /// for the line's reference at import.
    static func score(takeURL: URL, referenceURL: URL, line: DubLine) -> DubLineScore? {
        score(takeURL: takeURL, referenceURL: referenceURL, slug: line.slug, referenceOnset: line.speech?.start)
    }
}
