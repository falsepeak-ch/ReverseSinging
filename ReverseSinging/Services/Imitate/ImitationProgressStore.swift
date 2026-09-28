//
//  ImitationProgressStore.swift
//  ReverseSinging
//
//  Each sound's best score, kept between launches
//

import Combine
import Foundation

/// The best score reached on each sound. What the library's tiles show.
@MainActor
final class ImitationProgressStore: ObservableObject {

    static let shared = ImitationProgressStore()

    /// Best overall score per sound id, 0...100.
    @Published private(set) var bestScores: [String: Double]

    private let defaults: UserDefaults
    private static let key = "imitate.bestScores"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bestScores = defaults.dictionary(forKey: Self.key) as? [String: Double] ?? [:]
    }

    func best(for sound: ImitationSound) -> Double? {
        bestScores[sound.id]
    }

    /// Files a score. Returns whether it beat the previous best, so the result can say so.
    @discardableResult
    func record(_ score: Double, for sound: ImitationSound) -> Bool {
        let previous = bestScores[sound.id]
        guard previous.map({ score > $0 }) ?? true else { return false }

        bestScores[sound.id] = score
        defaults.set(bestScores, forKey: Self.key)
        // A first score is a score, not a record: there was nothing to beat.
        return previous != nil
    }
}
