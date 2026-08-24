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

    /// Bars as they were filed: linear peak amplitude, un-normalised.
    private(set) var bars: [Float] = []

    /// The loudest bar so far, which is what the trace is normalised against.
    private(set) var loudest: Float = 0

    /// The trace as it should be drawn: every bar against the take's own loudest moment.
    ///
    /// This is the second half of matching `WaveformSampler`, which normalises a finished file
    /// against its peak for exactly the same reason — a shape is about where the syllables
    /// are, not about how close the performer held the phone. Without it a take shouted into
    /// the mic and the same take murmured would draw at completely different heights, and the
    /// trace would jump the moment recording stopped and the file was sampled properly.
    ///
    /// The running maximum means an unusually loud moment rescales what is already drawn. That
    /// is correct rather than merely tolerable: it is what the finished waveform will do too,
    /// so the two agree at every point instead of only at the end.
    var normalizedBars: [Float] {
        guard loudest > 0 else { return bars }
        return bars.map { $0 / loudest }
    }

    init(barDuration: TimeInterval, maximumBars: Int) {
        self.barDuration = max(barDuration, 0.001)
        self.maximumBars = max(maximumBars, 1)
    }

    /// Files a peak amplitude sampled `elapsed` seconds into the take.
    ///
    /// - Parameter level: linear peak amplitude, 0...1 — `AudioRecorder.recordingPeak`, not
    ///   its dB meter level. The distinction is the whole reason the trace and the finished
    ///   waveform now draw the same shape.
    /// - Returns: whether anything changed, so a caller can skip republishing when the trace
    ///   is already full.
    @discardableResult
    mutating func add(_ level: Float, at elapsed: TimeInterval) -> Bool {
        let index = Int(max(0, elapsed) / barDuration)
        guard index < maximumBars else { return false }

        // A new loudest moment rescales the whole trace, so it has to republish even when the
        // bar it landed in was already that height.
        let raisedCeiling = level > loudest
        loudest = max(loudest, level)

        if index < bars.count {
            // Several ticks land in one bar on a short line: keep the loudest, the same way
            // the file sampler picks a peak rather than a mean.
            let merged = max(bars[index], level)
            guard merged != bars[index] || raisedCeiling else { return false }
            bars[index] = merged
        } else {
            // And one tick spans several bars on a long line. Holding the peak across them
            // keeps the trace from coming out as a comb of empty bars.
            while bars.count <= index { bars.append(level) }
        }

        return true
    }

    mutating func reset() {
        bars.removeAll(keepingCapacity: true)
        loudest = 0
    }
}
