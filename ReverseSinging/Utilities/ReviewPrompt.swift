//
//  ReviewPrompt.swift
//  ReverseSinging
//
//  When to ask for a star rating, and when to keep quiet
//

import Foundation
import StoreKit
import UIKit

/// Decides whether this is a good moment to ask for an App Store review.
///
/// Apple caps the prompt at three appearances a year and silently drops the rest, so the
/// only thing worth spending is *which* moments we spend it on. We ask people who have
/// come back to the app and shipped something: two opens and at least one shared dub, then
/// the ask lands on the third open, before they are deep in a take and would resent it.
///
/// The counters live in `UserDefaults` behind this one type, so nothing else has to know
/// the keys or the thresholds.
@MainActor
final class ReviewPrompt {

    static let shared = ReviewPrompt()

    private enum Key {
        static let openCount = "review.appOpenCount"
        static let sharedVideoCount = "review.sharedVideoCount"
        static let lastAskedAtOpenCount = "review.lastAskedAtOpenCount"
    }

    /// The open the ask lands on: two opens behind them, this one in front.
    private let opensBeforeAsking = 3

    /// At least one dub actually sent somewhere. Someone who has never shared has not
    /// finished anything yet, and has nothing to rate.
    private let sharesBeforeAsking = 1

    /// How many opens have to pass before we are willing to ask again. Apple would swallow
    /// a second ask anyway; this keeps us from burning the year's quota in one week.
    private let opensBetweenAsks = 10

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Signals

    /// A launch, or a return from the background. Called once per activation.
    func registerAppOpen() {
        defaults.set(openCount + 1, forKey: Key.openCount)
    }

    /// A dub that left the app — the share sheet reported the user actually sent it.
    func registerVideoShared() {
        defaults.set(sharedVideoCount + 1, forKey: Key.sharedVideoCount)
    }

    // MARK: - Asking

    /// Asks for a review if this moment qualifies. Safe to call from anywhere; a moment
    /// that does not qualify costs nothing.
    func requestIfAppropriate(trigger: String) {
        guard isEligible else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }

        defaults.set(openCount, forKey: Key.lastAskedAtOpenCount)
        SKStoreReviewController.requestReview(in: scene)
        AnalyticsManager.shared.trackReviewPromptRequested(
            trigger: trigger,
            openCount: openCount,
            sharedVideoCount: sharedVideoCount
        )
    }

    var isEligible: Bool {
        guard openCount >= opensBeforeAsking else { return false }
        guard sharedVideoCount >= sharesBeforeAsking else { return false }

        let lastAsked = defaults.integer(forKey: Key.lastAskedAtOpenCount)
        guard lastAsked == 0 || openCount - lastAsked >= opensBetweenAsks else { return false }

        return true
    }

    // MARK: - Counters

    var openCount: Int { defaults.integer(forKey: Key.openCount) }
    var sharedVideoCount: Int { defaults.integer(forKey: Key.sharedVideoCount) }

    #if DEBUG
    /// Lets a test start from a known state without reaching into `UserDefaults`.
    func resetForTesting() {
        for key in [Key.openCount, Key.sharedVideoCount, Key.lastAskedAtOpenCount] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
