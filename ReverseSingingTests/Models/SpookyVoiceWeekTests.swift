//
//  SpookyVoiceWeekTests.swift
//  ReverseSingingTests
//
//  Which days are Halloween, by the phone's own date
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Spooky Voice Week") @MainActor
struct SpookyVoiceWeekTests {

    private static let madrid = TimeZone(identifier: "Europe/Madrid")!
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private static let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    /// A wall-clock moment in the given time zone.
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, in zone: TimeZone = madrid) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Every day from the 24th of October to the 1st of November, both ends included.
    @Test(arguments: [
        (10, 24), (10, 25), (10, 28), (10, 31), (11, 1),
    ])
    func theSeasonDays(month: Int, day: Int) {
        #expect(SpookyVoiceWeek.isActive(on: Self.date(2026, month, day), in: Self.madrid))
    }

    /// The days either side, and the same dates in another year.
    @Test(arguments: [
        (2026, 10, 23), (2026, 11, 2), (2026, 6, 15), (2025, 10, 31), (2027, 10, 31),
    ])
    func outsideTheSeason(year: Int, month: Int, day: Int) {
        #expect(!SpookyVoiceWeek.isActive(on: Self.date(year, month, day), in: Self.madrid))
    }

    /// It starts at local midnight on the 24th and ends at local midnight after the 1st.
    @Test func edgesAreLocalMidnight() {
        #expect(!SpookyVoiceWeek.isActive(on: Self.date(2026, 10, 23, 23, 59), in: Self.madrid))
        #expect(SpookyVoiceWeek.isActive(on: Self.date(2026, 10, 24, 0, 0), in: Self.madrid))
        #expect(SpookyVoiceWeek.isActive(on: Self.date(2026, 11, 1, 23, 59), in: Self.madrid))
        #expect(!SpookyVoiceWeek.isActive(on: Self.date(2026, 11, 2, 0, 0), in: Self.madrid))
    }

    /// The same instant can be inside the season in Tokyo and still before it in Los Angeles.
    @Test func readByTheLocalDate() {
        let instant = Self.date(2026, 10, 24, 8, 0, in: Self.tokyo)
        #expect(SpookyVoiceWeek.isActive(on: instant, in: Self.tokyo))
        #expect(!SpookyVoiceWeek.isActive(on: instant, in: Self.losAngeles))
    }

    /// The card and the event link land on the same game.
    @Test func cardAndLinkShareADestination() {
        #expect(SpookyVoiceWeek.destination == .imitate)
        #expect(DeepLink(url: URL(string: "dubloon://event/spooky")!) == .game(SpookyVoiceWeek.destination))
    }
}
