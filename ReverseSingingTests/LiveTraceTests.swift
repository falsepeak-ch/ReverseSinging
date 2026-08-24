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
    /// to cover several bars — filling only the bar it lands in would draw a comb.
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

    /// Nothing changed means nothing to redraw — the view model skips republishing.
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
    }
}
