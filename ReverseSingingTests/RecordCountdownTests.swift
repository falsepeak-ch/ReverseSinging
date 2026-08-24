//
//  RecordCountdownTests.swift
//  ReverseSingingTests
//
//  The 3-2-1 slate played before the mic opens
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Record Countdown")
@MainActor
struct RecordCountdownTests {

    @Test func countsDownToTheGoBeat() async throws {
        var beats: [Int] = []
        try await RecordCountdown.run { beats.append($0) }

        #expect(beats == [3, 2, 1])
    }

    /// The mic opens when this returns, so the slate must be over by then — a tone still
    /// ringing into an open mic is a tone baked into the take.
    @Test func returnsOnlyAfterTheLastToneHasReleased() async throws {
        let start = Date()
        try await RecordCountdown.run { _ in }
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed >= RecordCountdown.duration)
    }

    /// Pressing record again during the count is a change of mind. Nothing has been recorded,
    /// so the count is abandoned and — critically — the caller never reaches `beginRecording`.
    @Test func cancellingStopsTheCountBeforeItFinishes() async {
        let task = Task { @MainActor () -> (beats: [Int], threw: Bool) in
            var beats: [Int] = []
            do {
                try await RecordCountdown.run { beats.append($0) }
                return (beats, false)
            } catch {
                return (beats, true)
            }
        }

        // Well inside the first beat's gap.
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        let result = await task.value

        #expect(result.beats.count < RecordCountdown.beats)
        // Throwing is the part that matters: it is what stops the caller opening the mic.
        #expect(result.threw)
    }

    /// The count has to be short enough that a performer waits it out rather than fighting it.
    @Test func staysUnderTwoSeconds() {
        #expect(RecordCountdown.duration < 2.0)
    }
}
