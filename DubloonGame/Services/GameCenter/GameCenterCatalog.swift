//
//  GameCenterCatalog.swift
//  DubloonGame
//
//  The leaderboards and achievements, by the identifiers App Store Connect knows them by.
//

import Foundation

/// Every Game Center identifier the game reports to.
///
/// They have to match App Store Connect byte for byte; `fastlane/game_center/setup_game_center.rb`
/// creates them there from the same list, with their titles and artwork.
nonisolated enum GameCenterCatalog {

    /// The leaderboards, one per mini game plus the whole show and a weekly race.
    enum Leaderboard: String, CaseIterable {
        /// Every sound's best score plus every dubbed line's best: the whole show.
        case showPoints = "dubloon.game.leaderboard.show_points"
        /// Each sound's best score, added up. Rewards trying everything and getting it right.
        case imitationPoints = "dubloon.game.leaderboard.imitation_points"
        /// Each dubbed line's best score, added up, across every scene.
        case dubPoints = "dubloon.game.leaderboard.dub_points"
        /// Stars won in Sound Imitation, out of three a sound.
        case imitationStars = "dubloon.game.leaderboard.imitation_stars"
        /// Points from every take this week; a recurring leaderboard that restarts each Monday.
        case weekly = "dubloon.game.leaderboard.weekly_show"
    }

    /// The achievements, from a first take to every star.
    enum Achievement: String, CaseIterable {
        case firstTake = "dubloon.game.achievement.first_take"
        case firstThreeStars = "dubloon.game.achievement.first_three_stars"
        case tenThreeStars = "dubloon.game.achievement.ten_three_stars"
        case everySound = "dubloon.game.achievement.every_sound"
        case firstDub = "dubloon.game.achievement.first_dub"
        case greatDub = "dubloon.game.achievement.great_dub"
        case sceneWrapped = "dubloon.game.achievement.scene_wrapped"
        case perfectTake = "dubloon.game.achievement.perfect_take"
        case hundredStars = "dubloon.game.achievement.hundred_stars"
    }
}
