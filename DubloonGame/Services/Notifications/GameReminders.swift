//
//  GameReminders.swift
//  DubloonGame
//
//  Local notifications: the evening show, and the last day of the weekly race.
//

import Foundation
import UserNotifications

/// The game's reminders. All local: nothing is sent from a server and nothing leaves the phone.
///
/// - **Showtime**, one an evening for the next week, each naming a different sound the player
///   has not yet got three stars on (or a scene, now and then). Today's is skipped once they
///   have played today, so a reminder never nags someone who already came.
/// - **The weekly race**, Sunday afternoon, only while the player has points on this week's
///   board, telling them where they stand before Game Center restarts it on Monday.
///
/// Repeating triggers cannot change their text, so the week is laid out as one-off requests
/// and laid out again every time the app goes to the background.
@MainActor
enum GameReminders {
    private static let prefix = "dubloon.game.reminder."
    private static let showHour = 18
    private static let lastPlayedKey = "game.reminders.lastPlayed"
    private static let primerShownKey = "game.reminders.primerShown"

    // MARK: - Permission

    /// Whether the primer should be shown now: once, after the first finished round, and only
    /// while iOS has not been asked.
    static func shouldOfferPrimer() async -> Bool {
        guard !UserDefaults.standard.bool(forKey: primerShownKey),
              GameScorebook.shared.hasPlayed else { return false }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .notDetermined
    }

    /// The primer's one button: iOS's own prompt, always.
    static func requestPermission() async {
        UserDefaults.standard.set(true, forKey: primerShownKey)
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        AnalyticsManager.shared.trackRemindersPermission(granted: granted)
        if granted { await reschedule() }
    }

    // MARK: - Schedule

    /// Notes that the player played, so tonight's reminder is skipped.
    static func didPlay() {
        UserDefaults.standard.set(Date(), forKey: lastPlayedKey)
    }

    /// Lays out the next week of reminders from scratch.
    static func reschedule(now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })

        let calendar = Calendar.current
        let playedToday = (UserDefaults.standard.object(forKey: lastPlayedKey) as? Date)
            .map { calendar.isDate($0, inSameDayAs: now) } ?? false
        var featured = soundsToFeature()

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  var fire = calendar.date(bySettingHour: showHour, minute: 0, second: 0, of: day) else { continue }
            if dayOffset == 0 && (playedToday || fire <= now) { continue }
            // A few minutes either side of the hour, so it reads as the host, not a timer.
            fire = fire.addingTimeInterval(Double((dayOffset * 7) % 20 - 10) * 60)

            let content = UNMutableNotificationContent()
            content.title = GameStrings.Reminder.showTitle
            if dayOffset % 3 == 2 {
                content.body = GameStrings.Reminder.showScene
            } else if let sound = featured.popLast() {
                content.body = GameStrings.Reminder.showSound(sound.name)
            } else {
                content.body = GameStrings.Reminder.showStage
            }
            content.sound = .default
            add(content, at: fire, id: "show.\(dayOffset)", calendar: calendar, center: center)
        }

        let points = GameScorebook.shared.weekPoints
        if points > 0,
           let lastDay = calendar.date(byAdding: .day, value: 6, to: GameScorebook.weekStart(of: now)),
           let fire = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: lastDay),
           fire > now {
            let content = UNMutableNotificationContent()
            content.title = GameStrings.Reminder.raceTitle
            content.body = GameStrings.Reminder.raceBody(points)
            content.sound = .default
            add(content, at: fire, id: "race", calendar: calendar, center: center)
        }
    }

    private static func add(_ content: UNMutableNotificationContent, at date: Date, id: String, calendar: Calendar, center: UNUserNotificationCenter) {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: prefix + id, content: content, trigger: trigger))
    }

    /// Sounds without three stars yet, shuffled; the tried-but-not-mastered ones last, so they
    /// are featured first.
    private static func soundsToFeature() -> [ImitationSound] {
        let store = ImitationProgressStore.shared
        let open = ImitationSoundLibrary.all.filter { (store.best(for: $0) ?? 0) < 85 }
        let tried = open.filter { store.best(for: $0) != nil }.shuffled()
        let untried = open.filter { store.best(for: $0) == nil }.shuffled()
        return untried + tried
    }
}
