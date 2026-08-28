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

    /// Gap between tones, about 100 bpm. Fast enough not to be a wait, slow enough to
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
    /// the take, 160 ms of perceived lateness is the cheaper of the two.
    ///
    /// Throws `CancellationError` when the task is cancelled. The user pressed record again,
    /// or left the screen. So the caller must not open the mic afterwards.
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

/// Drives one countdown at a time on behalf of a screen: owns the task, reports each beat,
/// and opens the mic only if the count runs all the way through.
///
/// Both games need exactly this, and the part worth getting right once is the cancel path,
/// a slate that is torn down must clear its beat *and* never reach `thenRecord`.
@MainActor
final class RecordSlate {

    private var task: Task<Void, Never>?
    private var onBeat: ((Int?) -> Void)?

    /// Whether a count is on screen right now.
    var isRunning: Bool { task != nil }

    /// Slate, then roll: three tones, `thenRecord` firing as the last one releases.
    ///
    /// `onBeat` receives the beat as each tone lands and `nil` once the count is over,
    /// whether it finished or was cancelled. Keep both closures weak: the slate outlives
    /// the call and is owned by the caller.
    func run(onBeat: @escaping (Int?) -> Void, thenRecord: @escaping () -> Void) {
        clear()
        self.onBeat = onBeat

        task = Task { [weak self] in
            do {
                try await RecordCountdown.run { beat in
                    onBeat(beat)
                    HapticManager.shared.light()
                }
            } catch {
                // Cancelled, `cancel` has already cleared the state.
                return
            }

            onBeat(nil)
            self?.task = nil
            self?.onBeat = nil
            thenRecord()
        }
    }

    /// Stops the count without opening the mic. Called from teardown paths too, so it has
    /// to be silent when nothing is running.
    func cancel() {
        guard task != nil else { return }

        clear()
        HapticManager.shared.light()
    }

    private func clear() {
        task?.cancel()
        task = nil
        onBeat?(nil)
        onBeat = nil
    }
}

