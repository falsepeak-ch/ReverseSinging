//
//  DubScorerTests.swift
//  ReverseSingingTests
//
//  The score says what actually happened in the take
//

import Testing
import AVFoundation
@testable import ReverseSinging

@Suite("Dub Scoring")
struct DubScorerTests {

    private let sampleRate = DubAudioLoader.canonicalFormat.sampleRate

    // MARK: - Fixtures

    /// A clip of `duration` seconds: silence, then a burst of tone at `amplitude`, then
    /// silence again. Stands in for "a person says a thing at this moment, this loudly".
    private func clip(
        duration: TimeInterval,
        speechFrom: TimeInterval,
        speechFor: TimeInterval,
        amplitude: Float = 0.6
    ) -> AVAudioPCMBuffer {
        let format = DubAudioLoader.canonicalFormat
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        let start = Int(speechFrom * format.sampleRate)
        let end = min(Int(frames), start + Int(speechFor * format.sampleRate))

        for frame in 0..<Int(frames) {
            samples[frame] = (frame >= start && frame < end)
                ? amplitude * sinf(2 * .pi * 220 * Float(frame) / Float(format.sampleRate))
                : 0
        }
        return buffer
    }

    /// A clip whose tone is chopped into syllables, bursts separated by gaps, so pacing has
    /// a shape to be right or wrong about.
    private func syllableClip(
        duration: TimeInterval,
        speechFrom: TimeInterval,
        syllables: [TimeInterval],
        gap: TimeInterval = 0.12,
        amplitude: Float = 0.6
    ) -> AVAudioPCMBuffer {
        let format = DubAudioLoader.canonicalFormat
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frames) { samples[frame] = 0 }

        var cursor = speechFrom
        for syllable in syllables {
            let start = Int(cursor * format.sampleRate)
            let end = min(Int(frames), start + Int(syllable * format.sampleRate))
            for frame in start..<max(start, end) {
                samples[frame] = amplitude * sinf(2 * .pi * 220 * Float(frame) / Float(format.sampleRate))
            }
            cursor += syllable + gap
        }
        return buffer
    }

    private func line(lead: TimeInterval, duration: TimeInterval, speechFor: TimeInterval) -> DubLine {
        DubLine(
            index: 1,
            slug: "001_Tester",
            character: "Tester",
            caption: "Line",
            imageFile: "still.jpg",
            referenceAudioFile: "line.wav",
            startTime: 0,
            duration: duration,
            speech: DubSpeechWindow(start: lead, end: lead + speechFor)
        )
    }

    // MARK: - Timing

    /// The headline behaviour: come in with them and timing is full marks.
    @Test func comingInOnTheBeatScoresFullTiming() throws {
        let reference = clip(duration: 3, speechFrom: 0.8, speechFor: 1.5)
        let take = clip(duration: 3, speechFrom: 0.8, speechFor: 1.5)

        let score = try #require(DubScorer.score(
            take: take,
            reference: reference,
            line: line(lead: 0.8, duration: 3, speechFor: 1.5)
        ))

        #expect(score.timing >= 99, "timing was \(score.timing)")
    }

    /// Come in a beat late and the score has to say so, even though the mix will quietly
    /// slide the take back into place. The performer is told the truth.
    @Test func comingInLateCostsTiming() throws {
        let reference = clip(duration: 3, speechFrom: 0.8, speechFor: 1.5)
        let late = clip(duration: 3, speechFrom: 1.3, speechFor: 1.5)

        let score = try #require(DubScorer.score(
            take: late,
            reference: reference,
            line: line(lead: 0.8, duration: 3, speechFor: 1.5)
        ))

        #expect(score.timing < 80, "half a second late still scored \(score.timing)")
        #expect(score.timing > 0, "half a second late is not a total miss: \(score.timing)")
    }

    @Test func missingTheEntryEntirelyScoresZeroTiming() throws {
        let reference = clip(duration: 4, speechFrom: 0.3, speechFor: 1.0)
        let miles = clip(duration: 4, speechFrom: 2.5, speechFor: 1.0)

        let score = try #require(DubScorer.score(
            take: miles,
            reference: reference,
            line: line(lead: 0.3, duration: 4, speechFor: 1.0)
        ))

        #expect(score.timing == 0, "two seconds late scored \(score.timing)")
    }

    /// The tolerance curve itself, away from any audio.
    @Test func timingToleranceIsGenerousNearZeroAndSteepAfter() {
        #expect(DubScorer.timingScore(takeOnset: 1.0, referenceOnset: 1.0) == 100)
        #expect(DubScorer.timingScore(takeOnset: 1.05, referenceOnset: 1.0) == 100,
                "50 ms is below what anyone can see on a face")

        let quarterSecond = DubScorer.timingScore(takeOnset: 1.25, referenceOnset: 1.0)
        let halfSecond = DubScorer.timingScore(takeOnset: 1.5, referenceOnset: 1.0)

        #expect(quarterSecond > halfSecond, "\(quarterSecond) vs \(halfSecond)")
        #expect(halfSecond > 0)
        #expect(DubScorer.timingScore(takeOnset: 3.0, referenceOnset: 1.0) == 0)
    }

    /// Symmetric: early is as wrong as late.
    @Test func earlyIsPenalisedTheSameAsLate() {
        let early = DubScorer.timingScore(takeOnset: 0.7, referenceOnset: 1.0)
        let late = DubScorer.timingScore(takeOnset: 1.3, referenceOnset: 1.0)
        #expect(abs(early - late) < 0.001, "\(early) vs \(late)")
    }

    // MARK: - Pacing

    /// Same syllables in the same places: pacing should be near-perfect even though the two
    /// clips are different recordings.
    @Test func matchingSyllablesScoreWellOnPacing() throws {
        let reference = syllableClip(duration: 3, speechFrom: 0.4, syllables: [0.2, 0.3, 0.15, 0.25])
        let take = syllableClip(duration: 3, speechFrom: 0.4, syllables: [0.2, 0.3, 0.15, 0.25], amplitude: 0.9)

        let score = try #require(DubScorer.score(
            take: take,
            reference: reference,
            line: line(lead: 0.4, duration: 3, speechFor: 1.2)
        ))

        #expect(score.pacing > 80, "pacing was \(score.pacing)")
    }

    /// A take that comes in on the beat and then rushes through the line keeps its timing
    /// marks and loses pacing ones. This is the split the three components exist for.
    @Test func rushingAfterAGoodEntryCostsPacingNotTiming() throws {
        let reference = syllableClip(duration: 3, speechFrom: 0.4, syllables: [0.3, 0.3, 0.3, 0.3], gap: 0.25)
        let rushed = syllableClip(duration: 3, speechFrom: 0.4, syllables: [0.1, 0.1, 0.1, 0.1], gap: 0.05)

        let score = try #require(DubScorer.score(
            take: rushed,
            reference: reference,
            line: line(lead: 0.4, duration: 3, speechFor: 2.0)
        ))

        #expect(score.timing >= 99, "the entry was on the beat: \(score.timing)")
        #expect(score.pacing < score.timing, "pacing \(score.pacing) should trail timing \(score.timing)")
    }

    /// A one-word answer to a four-second line correlates beautifully over its one word.
    /// Coverage is what stops that from scoring as a good take.
    @Test func aTakeFarShorterThanTheLineIsMarkedDown() throws {
        let reference = syllableClip(duration: 4, speechFrom: 0.2, syllables: Array(repeating: 0.3, count: 8))
        let stub = syllableClip(duration: 4, speechFrom: 0.2, syllables: [0.3])

        let score = try #require(DubScorer.score(
            take: stub,
            reference: reference,
            line: line(lead: 0.2, duration: 4, speechFor: 3.2)
        ))

        #expect(score.pacing < 50, "a one-syllable stub scored \(score.pacing) on pacing")
    }

    // MARK: - Delivery

    /// Delivery is about shape, not level: the same performance recorded quietly must not be
    /// marked down for being quiet.
    @Test func deliveryIgnoresHowLoudTheTakeWasRecorded() throws {
        let reference = syllableClip(duration: 3, speechFrom: 0.3, syllables: [0.25, 0.4, 0.2], amplitude: 0.9)
        let quiet = syllableClip(duration: 3, speechFrom: 0.3, syllables: [0.25, 0.4, 0.2], amplitude: 0.08)

        let score = try #require(DubScorer.score(
            take: quiet,
            reference: reference,
            line: line(lead: 0.3, duration: 3, speechFor: 1.1)
        ))

        #expect(score.delivery > 70, "a quietly-recorded identical take scored \(score.delivery)")
        #expect(score.overall > 80, "and overall \(score.overall)")
    }

    // MARK: - Degenerate Input

    /// A performer who never opened their mouth gets zeros, not a crash and not a lucky
    /// correlation between two noise floors.
    @Test func aSilentTakeScoresZeroRatherThanCorrelatingNoise() throws {
        let reference = clip(duration: 2, speechFrom: 0.2, speechFor: 1.0)
        let silence = clip(duration: 2, speechFrom: 0, speechFor: 0, amplitude: 0)

        let score = try #require(DubScorer.score(
            take: silence,
            reference: reference,
            line: line(lead: 0.2, duration: 2, speechFor: 1.0)
        ))

        #expect(score.overall == 0, "silence scored \(score.overall)")
    }

    @Test func anUnreadableFileScoresNothingRatherThanZero() {
        let missing = URL(fileURLWithPath: "/dev/null/not-a-take.caf")

        #expect(DubScorer.score(
            takeURL: missing,
            referenceURL: missing,
            line: line(lead: 0, duration: 1, speechFor: 1)
        ) == nil, "a missing file is 'not measured', never a zero the user did not earn")
    }

    // MARK: - Aggregation

    @Test func theSceneScoreIsTheMeanOfTheTakesRecordedSoFar() {
        let scene = DubSceneScore(
            lines: [
                DubLineScore(slug: "a", timing: 100, pacing: 100, delivery: 100),
                DubLineScore(slug: "b", timing: 0, pacing: 0, delivery: 0)
            ],
            totalLines: 10
        )

        #expect(abs(scene.overall - 50) < 0.5, "got \(scene.overall)")
        #expect(scene.recordedLines == 2)
        #expect(!scene.isComplete, "two of ten is not a finished scene")
    }

    /// A half-finished scene must read as "you're doing well so far", not as a fail averaged
    /// over lines nobody has attempted.
    @Test func unrecordedLinesDoNotDragTheSceneScoreDown() {
        let scene = DubSceneScore(
            lines: [DubLineScore(slug: "a", timing: 100, pacing: 100, delivery: 100)],
            totalLines: 50
        )

        #expect(scene.overall == 100, "one perfect take out of fifty scored \(scene.overall)")
    }

    @Test func anEmptySceneScoresZeroWithoutDividingByZero() {
        let scene = DubSceneScore(lines: [], totalLines: 12)

        #expect(scene.overall == 0)
        #expect(scene.best == nil)
        #expect(!scene.isComplete)
    }

    @Test func timingIsWeightedAboveTheOtherComponents() {
        let goodEntry = DubLineScore(slug: "a", timing: 100, pacing: 0, delivery: 0)
        let goodEverythingElse = DubLineScore(slug: "b", timing: 0, pacing: 100, delivery: 100)

        #expect(goodEntry.overall > 0)
        #expect(goodEverythingElse.overall > goodEntry.overall,
                "two components still outweigh one, but timing is the heaviest single one")
        #expect(goodEntry.overall > DubLineScore(slug: "c", timing: 0, pacing: 100, delivery: 0).overall,
                "timing alone must beat pacing alone")
    }

    @Test func componentsAreClampedToTheScale() {
        let wild = DubLineScore(slug: "a", timing: 400, pacing: -80, delivery: .nan)

        #expect(wild.timing == 100)
        #expect(wild.pacing == 0)
        #expect(wild.delivery == 0)
        #expect(wild.overall.isFinite)
    }

    // MARK: - Grades

    @Test func gradesCoverTheWholeScaleWithoutAGap() {
        for score in stride(from: 0.0, through: 100.0, by: 0.5) {
            _ = DubGrade.forScore(score)
        }

        #expect(DubGrade.forScore(100) == .perfect)
        #expect(DubGrade.forScore(0) == .rough)
        #expect(DubGrade.forScore(88) == .perfect)
        #expect(DubGrade.forScore(87.9) == .great)
    }
}
