//
//  GameCenterManager.swift
//  DubloonGame
//
//  Signs the player in to Game Center, posts scores and achievements, opens the leaderboards.
//

import Combine
import GameKit
import UIKit

/// The game's link to Game Center.
///
/// Signing in happens once at launch, as Apple asks; if Game Center wants to show its own
/// sign-in sheet, it is held until the player asks for the leaderboards rather than thrown
/// over the stage on the first frame. Everything else does nothing until a player is signed
/// in, so a player who never uses Game Center never sees it.
@MainActor
final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()

    @Published private(set) var isAuthenticated = false
    /// Game Center's sign-in sheet, waiting to be shown when the player asks for it.
    private var pendingSignIn: UIViewController?

    private init() {}

    // MARK: - Sign in

    func authenticate() {
        #if DEBUG
        if ScreenshotMode.isActive { return }
        #endif
        // GameKit calls this on the main thread, but as a plain closure: hop explicitly so
        // Swift 6's isolation checks never trap on it.
        GKLocalPlayer.local.authenticateHandler = { @Sendable viewController, error in
            nonisolated(unsafe) let viewController = viewController
            let failed = error != nil
            Task { @MainActor in
                GameCenterManager.shared.authenticationDidChange(signIn: viewController, failed: failed)
            }
        }
    }

    private func authenticationDidChange(signIn: UIViewController?, failed: Bool) {
        pendingSignIn = signIn
        isAuthenticated = GKLocalPlayer.local.isAuthenticated
        if isAuthenticated {
            CrashReporter.shared.log("game center: signed in")
            // Scores won before signing in (or offline) count once the player is here.
            GameScorebook.shared.syncToGameCenter()
        } else if failed {
            CrashReporter.shared.log("game center: not signed in")
        }
    }

    // MARK: - Dashboard

    /// Opens Game Center on the leaderboards, or its sign-in sheet if the player is not in.
    func showLeaderboards() {
        if isAuthenticated {
            GKAccessPoint.shared.trigger(state: .leaderboards) {}
        } else if let pendingSignIn {
            present(pendingSignIn)
        }
    }

    func showAchievements() {
        guard isAuthenticated else { return showLeaderboards() }
        GKAccessPoint.shared.trigger(state: .achievements) {}
    }

    private func present(_ controller: UIViewController) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        top.present(controller, animated: true)
    }

    // MARK: - Reporting

    func submit(_ scores: [GameCenterCatalog.Leaderboard: Int]) {
        guard isAuthenticated, !scores.isEmpty else { return }
        for (leaderboard, value) in scores {
            let id = leaderboard.rawValue
            Task {
                do {
                    try await GKLeaderboard.submitScore(
                        value, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id]
                    )
                } catch {
                    CrashReporter.shared.log("game center: score for \(id) not sent: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Reports achievements at the given percentages. Game Center keeps the highest it has
    /// been told, so reporting again is harmless.
    func report(_ progress: [GameCenterCatalog.Achievement: Double]) {
        guard isAuthenticated, !progress.isEmpty else { return }
        Task {
            let achievements = progress.map { item, percent in
                let achievement = GKAchievement(identifier: item.rawValue)
                achievement.percentComplete = min(max(percent, 0), 100)
                achievement.showsCompletionBanner = true
                return achievement
            }
            do {
                try await GKAchievement.report(achievements)
            } catch {
                CrashReporter.shared.log("game center: achievements not sent: \(error.localizedDescription)")
            }
        }
    }
}
