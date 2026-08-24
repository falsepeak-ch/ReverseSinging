//
//  LiveTrace.swift
//  ReverseSinging
//
//  A take's shape as it is being performed, on a fixed time axis
//

import Foundation

/// Accumulates metering ticks into bars, one bar per fixed slice of time.
///
/// The point is that a bar is *final* once the take has moved past it. An earlier version kept
/// every raw tick and resampled the whole history into a bar count that itself grew as the
/// take ran — so twenty times a second every bar already on screen was rewritten, and the
/// trace shook and crawled instead of drawing itself. Anchoring each tick to the moment it was
/// sampled means the trace only ever grows to the right.
struct LiveTrace {

    /// Seconds of audio each bar stands for.
    let barDuration: TimeInterval

    /// Where the trace stops growing. A take can run indefinitely; the rail cannot.
    let maximumBars: Int

    private(set) var bars: [Float] = []

    init(barDuration: TimeInterval, maximumBars: Int) {
        self.barDuration = max(barDuration, 0.001)
        self.maximumBars = max(maximumBars, 1)
    }

    /// Files a level sampled `elapsed` seconds into the take.
    ///
    /// - Returns: whether anything changed, so a caller can skip republishing when the trace
    ///   is already full.
    @discardableResult
    mutating func add(_ level: Float, at elapsed: TimeInterval) -> Bool {
        let index = Int(max(0, elapsed) / barDuration)
        guard index < maximumBars else { return false }

        if index < bars.count {
            // Several ticks land in one bar on a short line: keep the loudest, the same way
            // the file sampler picks a peak rather than a mean.
            let merged = max(bars[index], level)
            guard merged != bars[index] else { return false }
            bars[index] = merged
        } else {
            // And one tick spans several bars on a long line. Holding the level across them is
            // right — it is the average power over exactly that stretch — and it keeps the
            // trace from coming out as a comb of empty bars.
            while bars.count <= index { bars.append(level) }
        }

        return true
    }

    mutating func reset() {
        bars.removeAll(keepingCapacity: true)
    }
}
