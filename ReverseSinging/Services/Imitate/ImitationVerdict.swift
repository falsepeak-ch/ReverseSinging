//
//  ImitationVerdict.swift
//  ReverseSinging
//
//  The word stamped on an impression
//

import CoreGraphics
import DubScoring
import SwiftUI

/// The rubber stamp that lands on the result: APPROVED, NAILED IT, FAILED…
///
/// Picked from a small pool per grade so a run of attempts doesn't read the same word every
/// time. The pick is seeded, so the result screen and the exported video agree.
nonisolated struct ImitationVerdict: Equatable, Sendable {

    enum Tint: Sendable {
        case good, fair, poor

        /// The editor's state colours, the only saturated ones the app uses.
        var rgb: (red: CGFloat, green: CGFloat, blue: CGFloat) {
            switch self {
            case .good: return (0.239, 0.639, 0.365)  // rsGood
            case .fair: return (0.780, 0.604, 0.227)  // rsCaution
            case .poor: return (0.898, 0.282, 0.302)  // rsRecord
            }
        }

        var cgColor: CGColor {
            CGColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        }

        var color: Color {
            Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        }
    }

    let word: String
    let tint: Tint
    /// Whether the result deserves confetti.
    let celebrates: Bool

    static func forGrade(_ grade: DubGrade, seed: Int) -> ImitationVerdict {
        let words: [String]
        let tint: Tint
        switch grade {
        case .perfect:
            words = [Strings.Imitate.Verdict.nailedIt, Strings.Imitate.Verdict.legendary]
            tint = .good
        case .great:
            words = [Strings.Imitate.Verdict.approved, Strings.Imitate.Verdict.certified]
            tint = .good
        case .good:
            words = [Strings.Imitate.Verdict.notBad]
            tint = .good
        case .close:
            words = [Strings.Imitate.Verdict.almost, Strings.Imitate.Verdict.soClose]
            tint = .fair
        case .rough:
            words = [Strings.Imitate.Verdict.failed, Strings.Imitate.Verdict.whatWasThat]
            tint = .poor
        }

        let index = abs(seed) % words.count
        return ImitationVerdict(
            word: words[index],
            tint: tint,
            celebrates: grade == .perfect || grade == .great || grade == .good
        )
    }
}
