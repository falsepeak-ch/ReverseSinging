//
//  GameScorebook.swift
//  DubloonGame
//
//  What the player has won, worked out from their takes, and sent on to Game Center.
//

import Foundation
import DubScoring

/// Keeps the points the leaderboards and achievements are built from.
///
/// Sound Imitation's bests already live in `ImitationProgressStore`; dubbed lines get their
/// bests here, by scene and line. On top of that the book keeps this week's points for the
/// weekly race, which Game Center restarts every Monday at midnight UTC (the recurring
/// leaderboard's schedule in App Store Connect), so the book does too.
///
/// Totals are recomputed from the bests on every take rather than added up, so a lost
/// submission or a reinstall that keeps the defaults never leaves a leaderboard short.
@MainActor
final class GameScorebook {
    static let shared = GameScorebook()

    private let defaults: UserDefaults
    private let imitation: ImitationProgressStore
    private let gameCenter: GameCenterManager

    private enum Key {
        static let dubBests = "game.scorebook.dubBests"
        static let weekStart = "game.scorebook.weekStart"
        static let weekPoints = "game.scorebook.weekPoints"
        static let takes = "game.scorebook.takes"
        static let perfect = "game.scorebook.perfect"
        static let wrappedScenes = "game.scorebook.wrappedScenes"
    }

    init(
        defaults: UserDefaults = .standard,
        imitation: ImitationProgressStore = .shared,
        gameCenter: GameCenterManager = .shared
    ) {
        self.defaults = defaults
        self.imitation = imitation
        self.gameCenter = gameCenter
    }

    // MARK: - Takes

    /// A judged impression. Call after the round has filed it with `ImitationProgressStore`.
    func recordImitation(score: Double, grade: DubGrade) {
        addTake(points: score, perfect: grade == .perfect)
        syncToGameCenter()
    }

    /// A judged dubbed line, keyed by scene and line so a better take replaces a worse one.
    func recordDub(score: Double, grade: DubGrade, scene: String, line: String, sceneIsWrapped: Bool) {
        var bests = dubBests
        let key = "\(scene)/\(line)"
        if score > bests[key, default: -1] {
            bests[key] = score
            defaults.set(bests, forKey: Key.dubBests)
        }
        if sceneIsWrapped {
            var wrapped = Set(defaults.stringArray(forKey: Key.wrappedScenes) ?? [])
            wrapped.insert(scene)
            defaults.set(Array(wrapped), forKey: Key.wrappedScenes)
        }
        addTake(points: score, perfect: grade == .perfect)
        syncToGameCenter()
    }

    private func addTake(points: Double, perfect: Bool) {
        GameReminders.didPlay()
        rollWeekIfNeeded()
        defaults.set(weekPoints + Int(points.rounded()), forKey: Key.weekPoints)
        defaults.set(takes + 1, forKey: Key.takes)
        if perfect { defaults.set(true, forKey: Key.perfect) }
    }

    // MARK: - Totals

    private var dubBests: [String: Double] {
        defaults.dictionary(forKey: Key.dubBests) as? [String: Double] ?? [:]
    }

    private var takes: Int { defaults.integer(forKey: Key.takes) }

    /// At least one take has been judged.
    var hasPlayed: Bool { takes > 0 }

    var weekPoints: Int {
        rollWeekIfNeeded()
        return defaults.integer(forKey: Key.weekPoints)
    }

    var imitationPoints: Int {
        Int(imitation.bestScores.values.reduce(0, +).rounded())
    }

    var dubPoints: Int {
        Int(dubBests.values.reduce(0, +).rounded())
    }

    var showPoints: Int { imitationPoints + dubPoints }

    private var starsPerSound: [Int] {
        ImitationSoundLibrary.all.map { sound in
            imitation.best(for: sound).map { ScorePart.stars(for: DubGrade.forScore($0)) } ?? 0
        }
    }

    // MARK: - Week

    /// Monday 00:00 UTC of the current week, the weekly leaderboard's own boundary.
    static func weekStart(of date: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func rollWeekIfNeeded() {
        let start = Self.weekStart()
        let stored = defaults.object(forKey: Key.weekStart) as? Date
        guard stored != start else { return }
        defaults.set(start, forKey: Key.weekStart)
        defaults.set(0, forKey: Key.weekPoints)
    }

    // MARK: - Game Center

    /// Sends every leaderboard and achievement as they stand. Cheap and idempotent: Game
    /// Center keeps a player's best on each board and the highest progress on each award.
    func syncToGameCenter() {
        guard gameCenter.isAuthenticated else { return }
        let stars = starsPerSound
        let starTotal = stars.reduce(0, +)
        let threeStarSounds = stars.filter { $0 == 3 }.count
        let triedSounds = imitation.bestScores.count
        let soundCount = max(ImitationSoundLibrary.all.count, 1)
        let bests = dubBests

        var scores: [GameCenterCatalog.Leaderboard: Int] = [
            .showPoints: showPoints,
            .imitationPoints: imitationPoints,
            .dubPoints: dubPoints,
            .imitationStars: starTotal,
        ]
        // An empty week is not a score: a zero would put the player on the board for nothing.
        if weekPoints > 0 { scores[.weekly] = weekPoints }
        gameCenter.submit(scores.filter { $0.value > 0 })

        let progress: [GameCenterCatalog.Achievement: Double] = [
            .firstTake: takes > 0 ? 100 : 0,
            .firstThreeStars: threeStarSounds > 0 ? 100 : 0,
            .tenThreeStars: Double(min(threeStarSounds, 10)) * 10,
            .everySound: Double(triedSounds) / Double(soundCount) * 100,
            .firstDub: bests.isEmpty ? 0 : 100,
            .greatDub: bests.values.contains { $0 >= 90 } ? 100 : 0,
            .sceneWrapped: (defaults.stringArray(forKey: Key.wrappedScenes) ?? []).isEmpty ? 0 : 100,
            .perfectTake: defaults.bool(forKey: Key.perfect) ? 100 : 0,
            .hundredStars: Double(min(starTotal, 100)),
        ]
        gameCenter.report(progress.filter { $0.value > 0 })
    }
}
