//
//  ReviewPrompt.swift
//  ReverseSinging
//
//  When to ask for a star rating, and when to keep quiet
//

import DubloonFoundation
import Foundation
import StoreKit
#if os(iOS)
import UIKit
#endif

/// Asks for an App Store review when `ReviewPromptPolicy` says the moment has come.
///
/// The policy owns the counters, their keys and the thresholds. This is the part that needs a
/// window scene and tells analytics the ask was made.
@MainActor
final class ReviewPrompt {

    static let shared = ReviewPrompt()

    private let policy: ReviewPromptPolicy

    init(defaults: UserDefaults = .standard) {
        policy = ReviewPromptPolicy(defaults: defaults)
    }

    // MARK: - Signals

    /// A launch, or a return from the background. Called once per activation.
    func registerAppOpen(now: Date = .now) {
        policy.registerAppOpen(now: now)
    }

    /// A dub that left the app — the share sheet reported the user actually sent it. The
    /// moment after is a proud one, so it is also a moment to ask.
    func registerVideoShared() {
        policy.registerShare()
        requestSoon(trigger: "video_shared")
    }

    /// A result the player can be proud of: a great reverse-singing score, an approved
    /// impression, a dead-on dub line. Counts for free players and paid ones alike.
    func registerWin() {
        policy.registerWin()
    }

    /// A win, and the moment to ask about it once the celebration has landed. For results that
    /// fill the screen, not for a line in the middle of a take.
    func celebrate(trigger: String) {
        policy.registerWin()
        requestSoon(trigger: trigger)
    }

    /// A dub pack of the user's own is in the library: one just imported, or one found there
    /// from before this was counted.
    func registerImportedPack() {
        policy.registerImportedPack()
    }

    /// Whether our own review note on the menu is for this person: they have imported a dub
    /// pack and used the app on at least three different days.
    var isBannerAudience: Bool { policy.isBannerAudience }

    /// Asks once the screen has had a moment: a score or verdict stays in view before anything
    /// covers it, and a cover closing has finished closing.
    func requestSoon(trigger: String) {
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            requestIfAppropriate(trigger: trigger)
        }
    }

    // MARK: - Asking

    /// Asks for a review if this moment qualifies. Safe to call from anywhere; a moment
    /// that does not qualify costs nothing.
    func requestIfAppropriate(trigger: String) {
        guard policy.isEligible else { return }
        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }

        policy.recordAsked()
        SKStoreReviewController.requestReview(in: scene)
        #else
        policy.recordAsked()
        SKStoreReviewController.requestReview()
        #endif
        AnalyticsManager.shared.trackReviewPromptRequested(
            trigger: trigger,
            openCount: policy.openCount,
            sharedVideoCount: policy.shareCount,
            winCount: policy.winCount
        )
    }

    #if DEBUG
    /// Lets a test start from a known state without reaching into `UserDefaults`.
    func resetForTesting() {
        policy.reset()
    }
    #endif
}
