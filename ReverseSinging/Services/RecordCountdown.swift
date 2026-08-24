//
//  RecordCountdown.swift
//  ReverseSinging
//
//  The 3-2-1 slate that runs between pressing record and the mic opening
//

import Foundation

/// The countdown played before a take.
///
/// Three tones on the beat, the last one a fifth higher. Performers lock onto a change in
/// pitch far more reliably than onto a number on screen, which is why the third tone is a
/// different sound rather than the same one again.
@MainActor
enum RecordCountdown {

    /// Tones in the count, the "go" included.
    static let beats = 3

    /// Gap between tones — about 100 bpm. Fast enough not to be a wait, slow enough to
    /// breathe in on.
    static let interval: TimeInterval = 0.6

    /// How long the whole slate takes, for callers that need to reserve the time.
    static var duration: TimeInterval {
        Double(beats - 1) * interval + UISound.countBeepGo.duration
    }

    /// Plays the slate, reporting each beat as it lands, and returns when the mic should open.
    ///
    /// Recording starts as the "go" tone *releases* rather than on its attack. The tones come
    /// out of the speaker, and a tone still ringing when the mic opens is a tone baked into
    /// the take — 160 ms of perceived lateness is the cheaper of the two.
    ///
    /// Throws `CancellationError` when the task is cancelled — the user pressed record again,
    /// or left the screen — so the caller must not open the mic afterwards.
    static func run(onBeat: (Int) -> Void) async throws {
        for beat in stride(from: beats, through: 1, by: -1) {
            try Task.checkCancellation()
            onBeat(beat)

            let isGo = beat == 1
            SoundManager.shared.play(isGo ? .countBeepGo : .countBeep)

            let wait = isGo ? UISound.countBeepGo.duration : interval
            try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }

        try Task.checkCancellation()
    }
}
