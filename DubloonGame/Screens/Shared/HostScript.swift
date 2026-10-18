//
//  HostScript.swift
//  DubloonGame
//
//  What the host says, and when: instructions before a take, a push during it, a verdict and
//  one useful tip after it.
//

import DubScoring

/// The host's lines for each moment of a round.
///
/// After a take she reacts to the grade and then points at the one part that held the score
/// back, the lowest of the parts it was marked on, so every result ends on something to try.
enum HostScript {

    static func reaction(to grade: DubGrade) -> String {
        switch grade {
        case .perfect, .great: GameStrings.Round.gradeTop
        case .good: GameStrings.Round.gradeGood
        case .close: GameStrings.Round.gradeClose
        case .rough: GameStrings.Round.gradeRough
        }
    }

    // MARK: - Sound Imitation

    /// The parts of an impression, in the order they are shown. Pitch is left out for a
    /// sound that has none to follow.
    static func parts(of score: ImitationScore) -> [ScorePart] {
        var parts = [ScorePart(id: "rhythm", title: Strings.Imitate.Part.rhythm, value: score.rhythm, tip: GameStrings.Round.tipRhythm)]
        if let pitch = score.pitch {
            parts.append(ScorePart(id: "pitch", title: Strings.Imitate.Part.pitch, value: pitch, tip: GameStrings.Round.tipPitch))
        }
        parts.append(ScorePart(id: "tone", title: Strings.Imitate.Part.tone, value: score.tone, tip: GameStrings.Round.tipTone))
        parts.append(ScorePart(id: "length", title: Strings.Imitate.Part.duration, value: score.duration, tip: GameStrings.Round.tipLength))
        return parts
    }

    static func result(_ score: ImitationScore) -> String {
        line(grade: score.grade, parts: parts(of: score))
    }

    // MARK: - Movie Scene Dub

    static func parts(of score: DubLineScore) -> [ScorePart] {
        [
            ScorePart(id: "timing", title: Strings.Dub.Score.timing, value: score.timing, tip: GameStrings.Round.tipTiming),
            ScorePart(id: "pacing", title: Strings.Dub.Score.pacing, value: score.pacing, tip: GameStrings.Round.tipPacing),
            ScorePart(id: "delivery", title: Strings.Dub.Score.delivery, value: score.delivery, tip: GameStrings.Round.tipDelivery),
        ]
    }

    static func result(_ score: DubLineScore) -> String {
        line(grade: score.grade, parts: parts(of: score))
    }

    // MARK: -

    /// The reaction, then the tip for the weakest part, unless every part was strong.
    private static func line(grade: DubGrade, parts: [ScorePart]) -> String {
        let reaction = reaction(to: grade)
        guard let weakest = parts.min(by: { $0.value < $1.value }), weakest.value < 85 else { return reaction }
        return reaction + " " + weakest.tip
    }
}

/// One marked part of a take, for the breakdown and the tip.
struct ScorePart: Identifiable, Equatable {
    let id: String
    let title: String
    let value: Double
    let tip: String
}
