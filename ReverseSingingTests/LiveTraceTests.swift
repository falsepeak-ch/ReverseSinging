//
//  LiveTraceTests.swift
//  ReverseSingingTests
//
//  The live take trace growing rather than redrawing itself
//

import Testing
@testable import ReverseSinging

@Suite("Live Trace")
struct LiveTraceTests {

    /// The whole point of the type. The trace used to be resampled from scratch on every
    /// metering tick, so bars already on screen changed value twenty times a second and the
    /// waveform visibly shook. A bar the take has moved past must never move again.
    @Test func barsAreFinalOnceThePlayheadHasPassedThem() {
        var trace = LiveTrace(barDuration: 0.1, maximumBars: 100)

        for tick in 0..<20 {
            trace.add(Float(tick % 7) / 7, at: Double(tick) * 0.05)
        }

        let settled = Array(trace.bars.prefix(5))

        // Another second of very loud audio, well past those bars.
        for tick in 20..<40 {
            trace.add(1.0, at: Double(tick) * 0.05)
        }

        #expect(Array(trace.bars.prefix(5)) == settled)
        #expect(trace.bars.count > settled.count)
    }

    /// Ticks arrive every 0.05 s. On a short line a bar is narrower than that, so one tick has
    /// to cover several bars, filling only the bar it lands in would draw a comb.
    @Test func oneTickFillsEveryBarItSpans() {
        var trace = LiveTrace(barDuration: 0.01, maximumBars: 100)

        trace.add(0.5, at: 0)
        trace.add(0.8, at: 0.05)

        #expect(trace.bars.count == 6)
        #expect(trace.bars.dropFirst().allSatisfy { $0 == 0.8 })
    }

    /// And on a long line several ticks land in the same bar. The file sampler keeps the peak
    /// of a bucket, so the live trace has to as well or the two would not be comparable.
    @Test func severalTicksInOneBarKeepTheLoudest() {
        var trace = LiveTrace(barDuration: 1.0, maximumBars: 10)

        trace.add(0.2, at: 0.1)
        trace.add(0.9, at: 0.4)
        trace.add(0.3, at: 0.7)

        #expect(trace.bars == [0.9])
    }

    /// A take can run indefinitely; the rail cannot.
    @Test func stopsGrowingAtTheCap() {
        var trace = LiveTrace(barDuration: 0.01, maximumBars: 5)

        #expect(trace.add(1, at: 0.02) == true)
        #expect(trace.add(1, at: 10) == false)
        #expect(trace.bars.count == 3)
    }

    /// Nothing changed means nothing to redraw. The view model skips republishing.
    @Test func reportsWhetherAnythingChanged() {
        var trace = LiveTrace(barDuration: 1.0, maximumBars: 10)

        #expect(trace.add(0.6, at: 0) == true)
        #expect(trace.add(0.4, at: 0.5) == false)
        #expect(trace.add(0.7, at: 0.9) == true)
    }

    @Test func resetClearsTheShape() {
        var trace = LiveTrace(barDuration: 0.1, maximumBars: 10)
        trace.add(1, at: 0.5)
        trace.reset()

        #expect(trace.bars.isEmpty)
        #expect(trace.loudest == 0, "a reset trace must not normalise the next take against the last one")
    }

    // MARK: - Normalisation

    /// The trace is drawn against the take's own loudest moment, which is exactly what
    /// `WaveformSampler` does to the finished file. Without this the live shape and the shape
    /// that replaces it when the mic closes are on different scales, and the waveform visibly
    /// changes height the instant recording stops.
    @Test func theTraceIsDrawnAgainstItsOwnLoudestMoment() {
        var trace = LiveTrace(barDuration: 0.1, maximumBars: 10)

        trace.add(0.1, at: 0)
        trace.add(0.4, at: 0.1)
        trace.add(0.2, at: 0.2)

        #expect(trace.normalizedBars == [0.25, 1.0, 0.5])
    }

    /// The same performance recorded quietly and loudly has to draw the same shape, a
    /// performer holding the phone closer is not a different take.
    @Test func normalisationIsIndependentOfHowLoudTheTakeWas() {
        var quiet = LiveTrace(barDuration: 0.1, maximumBars: 10)
        var loud = LiveTrace(barDuration: 0.1, maximumBars: 10)

        for (index, value) in [Float(0.02), 0.08, 0.04].enumerated() {
            quiet.add(value, at: Double(index) * 0.1)
            loud.add(value * 10, at: Double(index) * 0.1)
        }

        #expect(quiet.normalizedBars == loud.normalizedBars)
    }

    /// A new peak rescales bars already on screen, so it has to be reported as a change even
    /// when the bar it landed in was already that tall.
    @Test func aNewLoudestMomentRepublishesTheWholeTrace() {
        var trace = LiveTrace(barDuration: 1.0, maximumBars: 10)

        #expect(trace.add(0.3, at: 0) == true)
        #expect(trace.add(0.9, at: 0.5) == true, "same bar, but the ceiling moved")
        #expect(trace.normalizedBars == [1.0])
    }

    @Test func anEmptyTraceNormalisesWithoutDividingByZero() {
        var trace = LiveTrace(barDuration: 0.1, maximumBars: 10)
        #expect(trace.normalizedBars.isEmpty)

        trace.add(0, at: 0)
        #expect(trace.normalizedBars == [0])
    }
}
