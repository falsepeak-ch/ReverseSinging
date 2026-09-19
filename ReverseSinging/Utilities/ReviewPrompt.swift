//
//  ReviewPrompt.swift
//  ReverseSinging
//
//  When to ask for a star rating, and when to keep quiet
//

import DubloonFoundation
import Foundation
import StoreKit
import UIKit

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
    func registerAppOpen() {
        policy.registerAppOpen()
    }

    /// A dub that left the app — the share sheet reported the user actually sent it.
    func registerVideoShared() {
        policy.registerShare()
    }

    // MARK: - Asking

    /// Asks for a review if this moment qualifies. Safe to call from anywhere; a moment
    /// that does not qualify costs nothing.
    func requestIfAppropriate(trigger: String) {
        guard policy.isEligible else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }

        policy.recordAsked()
        SKStoreReviewController.requestReview(in: scene)
        AnalyticsManager.shared.trackReviewPromptRequested(
            trigger: trigger,
            openCount: policy.openCount,
            sharedVideoCount: policy.shareCount
        )
    }

    #if DEBUG
    /// Lets a test start from a known state without reaching into `UserDefaults`.
    func resetForTesting() {
        policy.reset()
    }
    #endif
}
