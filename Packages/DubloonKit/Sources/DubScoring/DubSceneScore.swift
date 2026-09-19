//
//  DubSceneScore.swift
//  DubScoring
//
//  A whole scene's worth of takes, summed up
//

/// A whole scene's worth of takes, summed up.
public struct DubSceneScore: Hashable, Sendable {

    /// Every line that has a take, scored.
    public let lines: [DubLineScore]

    /// How many lines the scene has in total, recorded or not.
    public let totalLines: Int

    public init(lines: [DubLineScore], totalLines: Int) {
        self.lines = lines
        self.totalLines = totalLines
    }

    public var recordedLines: Int { lines.count }

    /// True once every line in the scene has been dubbed.
    public var isComplete: Bool { totalLines > 0 && recordedLines >= totalLines }

    /// The scene's score: the mean of the takes recorded so far.
    ///
    /// Deliberately *not* averaged over the un-recorded lines. A half-finished scene should
    /// read as "you're doing well so far", not as a fail the user can only climb out of by
    /// finishing. The completeness of the scene is already shown right next to it.
    public var overall: Double {
        guard !lines.isEmpty else { return 0 }
        let total = lines.reduce(0) { $0 + $1.overall }
        return (total / Double(lines.count) * 10).rounded() / 10
    }

    public var timing: Double { average(\.timing) }
    public var pacing: Double { average(\.pacing) }
    public var delivery: Double { average(\.delivery) }

    /// The band `overall` falls in.
    public var grade: DubGrade { DubGrade.forScore(overall) }

    /// The take that came out best, for something to celebrate.
    public var best: DubLineScore? { lines.max { $0.overall < $1.overall } }

    /// The take most worth another go.
    public var weakest: DubLineScore? { lines.min { $0.overall < $1.overall } }

    private func average(_ key: KeyPath<DubLineScore, Double>) -> Double {
        guard !lines.isEmpty else { return 0 }
        return lines.reduce(0) { $0 + $1[keyPath: key] } / Double(lines.count)
    }
}
