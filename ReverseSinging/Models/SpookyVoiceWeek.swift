//
//  SpookyVoiceWeek.swift
//  ReverseSinging
//
//  When the Halloween dressing is up, and where it leads
//

import Foundation

/// Spooky Voice Week: the Halloween card on the menu and the header over the sound library.
///
/// It adds no content. The ghost, zombie, wolf and owl were already in Sound Imitation and
/// *Camp Rules* already in the dub library; the week dresses them up and points at them. Every
/// question about it, whether it is on and where it goes, is answered here and nowhere else.
///
/// The season runs from 24 October to 1 November 2026 inclusive, by the date on the phone:
/// someone in Tokyo gets it a night before someone in Madrid, as they would any local holiday.
/// Outside those days the app is exactly what it was.
enum SpookyVoiceWeek {

    /// The first and last day, inclusive, as Gregorian year, month, day.
    static let firstDay = Day(year: 2026, month: 10, day: 24)
    static let lastDay = Day(year: 2026, month: 11, day: 1)

    /// The game the card, and `dubloon://event/spooky`, both open.
    static let destination: GameMode = .imitate

    /// Debug builds only: `-HalloweenPreview YES` turns the season on whatever the date.
    static let previewArgument = "HalloweenPreview"

    /// Whether the week is on for this date, read in the given time zone.
    ///
    /// Always the Gregorian calendar: a phone set to the Buddhist or Japanese calendar numbers
    /// its years differently, and the dates above are Gregorian.
    static func isActive(on date: Date, in timeZone: TimeZone = .current) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return false }
        return (firstDay...lastDay).contains(Day(year: year, month: month, day: day))
    }

    /// Whether the week is on right now, on this phone.
    static var isActiveNow: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: previewArgument) { return true }
        #endif
        return isActive(on: Date())
    }

    /// The season's dates, short and in the user's language: "Oct 24 – Nov 1", "24 oct – 1 nov".
    /// Formatted rather than translated, so every language gets its own date order for free.
    static func dateRangeText(locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        guard let start = calendar.date(from: firstDay.components),
              let end = calendar.date(from: lastDay.components) else { return "" }
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateTemplate = "MMMd"
        return formatter.string(from: start, to: end)
    }

    /// A calendar day, ordered by date.
    struct Day: Comparable, Sendable {
        let year: Int
        let month: Int
        let day: Int

        var components: DateComponents { DateComponents(year: year, month: month, day: day, hour: 12) }

        static func < (lhs: Day, rhs: Day) -> Bool {
            (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
        }
    }
}
