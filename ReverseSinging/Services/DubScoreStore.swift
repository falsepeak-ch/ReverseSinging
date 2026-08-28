//
//  DubScoreStore.swift
//  ReverseSinging
//
//  Scores kept beside the takes they belong to
//

import Foundation

/// Reads and writes a pack's scores.
///
/// Stored next to the takes rather than in `UserDefaults`, for one reason: deleting a pack
/// already removes its takes directory, so the scores go with them. A score that outlived the
/// recording it described would reappear against the next take of the same line.
///
/// A miss is never an error. A scene with no scores file is a scene nobody has dubbed yet, and
/// a file that fails to decode is one written by a build that stored something else, both
/// mean "no scores", and both are fixed by recording a line.
nonisolated struct DubScoreStore {

    static let shared = DubScoreStore()

    private static let filename = "scores.json"

    private init() {}

    private func url(for packID: UUID) -> URL {
        AudioFileManager.shared.dubTakesDirectory(packID: packID).appendingPathComponent(Self.filename)
    }

    // MARK: - Reading

    /// Every score stored for a pack, keyed by line slug.
    func scores(forPackID packID: UUID) -> [String: DubLineScore] {
        guard let data = try? Data(contentsOf: url(for: packID)) else { return [:] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let stored = try? decoder.decode([DubLineScore].self, from: data) else { return [:] }
        return Dictionary(stored.map { ($0.slug, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    /// A pack's scores rolled up, in the pack's own line order.
    func sceneScore(for pack: DubPack) -> DubSceneScore {
        let stored = scores(forPackID: pack.id)
        return DubSceneScore(
            lines: pack.lines.compactMap { stored[$0.slug] },
            totalLines: pack.lines.count
        )
    }

    // MARK: - Writing

    /// Records one line's score, replacing whatever was there.
    func save(_ score: DubLineScore, forPackID packID: UUID) {
        var stored = scores(forPackID: packID)
        stored[score.slug] = score
        write(stored, forPackID: packID)
    }

    /// Forgets a line's score, so a scene average never counts a performance whose take is
    /// gone. Covered by `scoresRoundTripAndAreForgottenWithTheirTake`.
    func remove(slug: String, forPackID packID: UUID) {
        var stored = scores(forPackID: packID)
        guard stored.removeValue(forKey: slug) != nil else { return }
        write(stored, forPackID: packID)
    }

    private func write(_ scores: [String: DubLineScore], forPackID packID: UUID) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // Sorted so the file is stable between writes and readable when something goes wrong.
        guard let data = try? encoder.encode(scores.values.sorted { $0.slug < $1.slug }) else { return }
        try? data.write(to: url(for: packID), options: .atomic)
    }
}
