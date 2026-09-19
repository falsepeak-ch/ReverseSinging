//
//  DubLineScore.swift
//  DubScoring
//
//  How close one take came to the line it replaces
//

public import Foundation

/// How well one take matched the line it replaces, broken into the three things a dub is
/// actually judged on.
///
/// Kept separate rather than collapsed to one number on the way in, because "70" tells a
/// performer nothing they can act on and "you came in late" tells them everything.
public struct DubLineScore: Codable, Hashable, Identifiable, Sendable {

    /// The line this scores, by slug. The same key the take file is named with.
    public let slug: String

    /// Did you come in on the beat? Distance between where the original's first word lands and
    /// where yours does, before any alignment is applied.
    public let timing: Double

    /// Did your syllables land where theirs did? Correlation of the two energy shapes once
    /// both are lined up at the onset, which is what separates a good read from a rushed one.
    public let pacing: Double

    /// Did you play it like they did, same swells, same drops? How closely the loudness
    /// contour tracks the original's.
    public let delivery: Double

    /// When it was measured, so a stored score can be thrown away if the take is newer.
    public let measuredAt: Date

    public var id: String { slug }

    /// The single number shown to the user, 0...100.
    ///
    /// Timing carries the most weight because it is what makes a dub read as a dub: a line
    /// delivered beautifully a second late is worse to watch than a flat one that lands on the
    /// mouth. Pacing comes next. Delivery counts least: it is the most subjective of the
    /// three, and the one a phone mic distorts most.
    public var overall: Double {
        let combined = timing * 0.45 + pacing * 0.35 + delivery * 0.20
        return (combined * 10).rounded() / 10
    }

    /// The band `overall` falls in.
    public var grade: DubGrade { DubGrade.forScore(overall) }

    public init(
        slug: String,
        timing: Double,
        pacing: Double,
        delivery: Double,
        measuredAt: Date = Date()
    ) {
        self.slug = slug
        self.timing = Self.clamp(timing)
        self.pacing = Self.clamp(pacing)
        self.delivery = Self.clamp(delivery)
        self.measuredAt = measuredAt
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(100, max(0, value))
    }
}
