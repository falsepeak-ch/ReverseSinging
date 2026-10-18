//
//  GameStrings.swift
//  DubloonGame
//
//  The game's own copy. Everything else is the shared `Strings`.
//

import Foundation

nonisolated enum GameStrings {
    private static func string(_ key: String, _ comment: String) -> String {
        NSLocalizedString(key, tableName: "Game", comment: comment)
    }

    enum Host {
        static let greeting = string("game.host.greeting", "What the game-show host says on the home stage, in a speech panel above the two games")
        static let outOfTakes = string("game.host.outOfTakes", "What the host says on the home stage once the free takes are used up")
    }

    enum Imitate {
        static let prompt = string("game.imitate.prompt", "Big caption on the stage before the first attempt at a sound")
    }

    enum Dub {
        /// Takes the line number and the scene's line count.
        static func lineOf(_ line: Int, _ total: Int) -> String {
            String(format: string("game.dub.lineOf", "Which line of the scene is up, e.g. 'Line 2 of 6'"), line, total)
        }
    }

    static let pickSound = string("game.pickSound", "Title of the screen where the player picks a sound to imitate")
    static let pickScene = string("game.pickScene", "Title of the screen where the player picks a movie scene to dub")
    static let leaderboards = string("game.leaderboards", "Accessibility label of the trophy on the home stage that opens the Game Center leaderboards")
    static let nextSound = string("game.nextSound", "Button after a result: go on to the next sound")
    /// Through the 3-2-1, before the mic opens.
    static let getReady = string("game.getReady", "Big caption on the stage during the 3-2-1 count before recording")

    /// What the host says during a round. See `HostScript`.
    enum Round {
        static func imitateReady(_ sound: String) -> String {
            String(format: string("game.host.imitate.ready", "Instruction before an impression. %@ is the sound's name"), sound)
        }
        static func dubReady(_ character: String) -> String {
            String(format: string("game.host.dub.ready", "Instruction before dubbing a line. %@ is the character's name"), character)
        }
        static let countIn = string("game.host.countIn", "Said by the host during the 3-2-1 before recording")
        static let imitateRecording = string("game.host.imitate.recording", "Encouragement while the player makes the sound")
        static let dubRecording = string("game.host.dub.recording", "Encouragement while the player dubs a line")
        static let scoring = string("game.host.scoring", "Said while the take is being judged")
        static let gradeTop = string("game.host.grade.top", "Reaction to a top score")
        static let gradeGood = string("game.host.grade.good", "Reaction to a good score")
        static let gradeClose = string("game.host.grade.close", "Reaction to a near miss")
        static let gradeRough = string("game.host.grade.rough", "Playful reaction to a poor score")
        static let tipRhythm = string("game.host.tip.rhythm", "Tip when rhythm was the weakest part of an impression")
        static let tipPitch = string("game.host.tip.pitch", "Tip when pitch was the weakest part")
        static let tipTone = string("game.host.tip.tone", "Tip when tone was the weakest part")
        static let tipLength = string("game.host.tip.length", "Tip when length was the weakest part")
        static let tipTiming = string("game.host.tip.timing", "Tip when timing was the weakest part of a dub")
        static let tipPacing = string("game.host.tip.pacing", "Tip when pacing was the weakest part of a dub")
        static let tipDelivery = string("game.host.tip.delivery", "Tip when delivery was the weakest part of a dub")
        static let sceneDone = string("game.host.dub.sceneDone", "Said when every line of the scene is dubbed")
        static let dubAgain = string("game.host.dub.again", "Said on a line that already has a take, inviting another go")
    }

    enum Settings {
        static let fewerSounds = string("game.settings.fewerSounds", "Settings switch: play fewer of the game's sound effects")
        static let fewerSoundsDesc = string("game.settings.fewerSounds.desc", "Under that switch: what it keeps and what it drops")
        static let soundEffectsDesc = string("game.settings.soundEffects.desc", "Under the Sound effects switch: what the game's sounds are")
        static let unlockDesc = string("game.settings.unlock.desc", "Under Unlock Dubloon Pro in the game's settings: what Pro gives")
    }

    /// The reminders and the card that asks for them. See `GameReminders`.
    enum Reminder {
        static let primerTitle = string("game.reminder.primer.title", "Title of the card that explains reminders before iOS asks for notification permission")
        static let primerBody = string("game.reminder.primer.body", "Body of that card: what the reminders are and that they can be turned off in Settings")
        static let primerContinue = string("game.reminder.primer.continue", "The card's only button; it opens the iOS notification prompt")
        static let showTitle = string("game.reminder.show.title", "Title of the evening reminder notification")
        static func showSound(_ sound: String) -> String {
            String(format: string("game.reminder.show.sound", "Evening reminder naming a sound to imitate. %@ is the sound's name"), sound)
        }
        static let showScene = string("game.reminder.show.scene", "Evening reminder inviting the player to dub a movie scene")
        static let showStage = string("game.reminder.show.stage", "Evening reminder when there is no particular sound to name")
        static let raceTitle = string("game.reminder.race.title", "Title of the Sunday reminder that the weekly leaderboard ends tomorrow")
        static func raceBody(_ points: Int) -> String {
            String(format: string("game.reminder.race.body", "Body of that reminder. %d is the player's points this week"), points)
        }
    }

    /// The brand line under "Dubloon" at the top of the stage.
    static let subtitle = string("game.subtitle", "Under the app name on the home stage: 'Dubloon' / 'The Game'")
}
