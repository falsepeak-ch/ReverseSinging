//
//  DubScore.swift
//  ReverseSinging
//
//  How close a take — and a whole scene — came to the original
//

import Foundation

/// How well one take matched the line it replaces, broken into the three things a dub is
/// actually judged on.
///
/// Kept separate rather than collapsed to one number on the way in, because "70" tells a
/// performer nothing they can act on and "you came in late" tells them everything.
nonisolated struct DubLineScore: Codable, Hashable, Identifiable {

    /// The line this scores, by slug — the same key the take file is named with.
    let slug: String

    /// Did you come in on the beat? Distance between where the original's first word lands and
    /// where yours does, before any alignment is applied.
    let timing: Double

    /// Did your syllables land where theirs did? Correlation of the two energy shapes once
    /// both are lined up at the onset, which is what separates a good read from a rushed one.
    let pacing: Double

    /// Did you play it like they did — same swells, same drops? How closely the loudness
    /// contour tracks the original's.
    let delivery: Double

    /// When it was measured, so a stored score can be thrown away if the take is newer.
    let measuredAt: Date

    var id: String { slug }

    /// The single number shown to the user, 0...100.
    ///
    /// Timing carries the most weight because it is what makes a dub read as a dub: a line
    /// delivered beautifully a second late is worse to watch than a flat one that lands on the
    /// mouth. Pacing comes next, and delivery — the most subjective of the three, and the one
    /// a phone mic distorts most — counts least.
    var overall: Double {
        let combined = timing * 0.45 + pacing * 0.35 + delivery * 0.20
        return (combined * 10).rounded() / 10
    }

    init(
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

/// A whole scene's worth of takes, summed up.
nonisolated struct DubSceneScore: Hashable {

    /// Every line that has a take, scored.
    let lines: [DubLineScore]

    /// How many lines the scene has in total, recorded or not.
    let totalLines: Int

    var recordedLines: Int { lines.count }

    /// True once every line in the scene has been dubbed.
    var isComplete: Bool { totalLines > 0 && recordedLines >= totalLines }

    /// The scene's score: the mean of the takes recorded so far.
    ///
    /// Deliberately *not* averaged over the un-recorded lines. A half-finished scene should
    /// read as "you're doing well so far", not as a fail the user can only climb out of by
    /// finishing — the completeness of the scene is already shown right next to it.
    var overall: Double {
        guard !lines.isEmpty else { return 0 }
        let total = lines.reduce(0) { $0 + $1.overall }
        return (total / Double(lines.count) * 10).rounded() / 10
    }

    var timing: Double { average(\.timing) }
    var pacing: Double { average(\.pacing) }
    var delivery: Double { average(\.delivery) }

    /// The take that came out best, for something to celebrate.
    var best: DubLineScore? { lines.max { $0.overall < $1.overall } }

    /// The take most worth another go.
    var weakest: DubLineScore? { lines.min { $0.overall < $1.overall } }

    private func average(_ key: KeyPath<DubLineScore, Double>) -> Double {
        guard !lines.isEmpty else { return 0 }
        return lines.reduce(0) { $0 + $1[keyPath: key] } / Double(lines.count)
    }
}

// MARK: - Grades

/// The band a score falls in: a colour, a short label, and a line of feedback.
///
/// One ladder for the whole dub feature, so the record screen, the line list and the scene
/// summary can never disagree about whether 74 is good.
nonisolated enum DubGrade: String, CaseIterable {
    case perfect
    case great
    case good
    case close
    case rough

    static func forScore(_ score: Double) -> DubGrade {
        switch score {
        case 88...:    return .perfect
        case 74..<88:  return .great
        case 58..<74:  return .good
        case 40..<58:  return .close
        default:       return .rough
        }
    }

    /// Two or three characters, for a chip beside a line.
    var badge: String {
        switch self {
        case .perfect: return "A+"
        case .great:   return "A"
        case .good:    return "B"
        case .close:   return "C"
        case .rough:   return "D"
        }
    }

    var title: String {
        switch self {
        case .perfect: return Strings.Dub.Score.gradePerfect
        case .great:   return Strings.Dub.Score.gradeGreat
        case .good:    return Strings.Dub.Score.gradeGood
        case .close:   return Strings.Dub.Score.gradeClose
        case .rough:   return Strings.Dub.Score.gradeRough
        }
    }
}
