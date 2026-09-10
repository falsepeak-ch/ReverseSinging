//
//  DubBackingBalanceTests.swift
//  ReverseSingingTests
//
//  One level for the whole scene, set against that scene's own dialogue
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

@Suite("Backing Balance")
struct DubBackingBalanceTests {

    private let sampleRate: Double = 44_100

    /// A bed whose amplitude follows `envelope`, one entry per second.
    private func bed(envelope: [Float]) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2))
        let total = AVAudioFrameCount(Double(envelope.count) * sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total))
        buffer.frameLength = total

        let channels = try #require(buffer.floatChannelData)
        for frame in 0..<Int(total) {
            let amplitude = envelope[min(envelope.count - 1, frame / Int(sampleRate))]
            let sample = amplitude * sinf(2 * .pi * 300 * Float(frame) / Float(sampleRate))
            channels[0][frame] = sample
            channels[1][frame] = sample
        }
        return buffer
    }

    private func line(_ index: Int, at start: TimeInterval, for duration: TimeInterval) -> DubLine {
        DubLine(
            index: index,
            slug: "\(index)_Tester",
            character: "Tester",
            caption: "line \(index)",
            imageFile: "\(index).jpg",
            referenceAudioFile: "\(index).wav",
            startTime: start,
            duration: duration
        )
    }

    private func decibels(_ gain: Float) -> Float { 20 * log10f(gain) }

    /// RMS of a sine is its amplitude over root two.
    private func rms(_ amplitude: Float) -> Float { amplitude / Float(2).squareRoot() }

    // MARK: - Placing

    /// A bed arriving level with the dialogue — a feature's music and effects stem — is put
    /// where a mixer would put it rather than where it came in.
    @Test func aBedLevelWithTheDialogueIsBroughtUnderIt() {
        let gain = DubBackingBalance.bedGain(bed: 0.2, dialogue: 0.2)

        #expect(abs(decibels(gain) - DubBackingBalance.bedBelowDialogue) < 0.01)
    }

    /// The starter scene ships one of these: a bed already further under its dialogue than the
    /// target. Turning it up would be the app overruling whoever cut the pack.
    @Test func aBedAlreadyWellUnderTheDialogueIsNeverBoosted() {
        #expect(DubBackingBalance.bedGain(bed: 0.004, dialogue: 0.2) == 1)
    }

    /// Two packs whose beds arrive ten decibels apart, both too loud, land in the same place
    /// against their own dialogue. This is the entire point of measuring rather than
    /// multiplying: a fixed gain would have preserved the distance between them.
    @Test func twoPacksWithVeryDifferentBedsEndUpInTheSamePlace() {
        let dialogue: Float = 0.25

        let loudSettled = decibels(0.5 * DubBackingBalance.bedGain(bed: 0.5, dialogue: dialogue))
        let quieterSettled = decibels(0.15 * DubBackingBalance.bedGain(bed: 0.15, dialogue: dialogue))

        #expect(abs(loudSettled - quieterSettled) < 0.01)
    }

    @Test func theCutIsBounded() {
        #expect(DubBackingBalance.bedGain(bed: 0.9, dialogue: 0.001) == DubBackingBalance.minimumBedGain)
    }

    /// Nothing to measure against: the bed falls back rather than being left at full.
    @Test func aPackThatCannotBeMeasuredFallsBack() {
        #expect(DubBackingBalance.bedGain(bed: 0.3, dialogue: nil) == DubBackingBalance.fallbackBedGain)
        #expect(DubBackingBalance.bedGain(bed: nil, dialogue: 0.3) == DubBackingBalance.fallbackBedGain)
        #expect(DubBackingBalance.bedGain(bed: 0, dialogue: 0.3) == DubBackingBalance.fallbackBedGain)
    }

    // MARK: - Measuring under the lines

    /// The bed is measured where the dialogue is, not where it is loudest. A pack cut from a
    /// finished mix is quiet under every line and loud between them, and it is the quiet part
    /// that decides where the bed goes.
    @Test func theBedIsMeasuredUnderTheLinesRatherThanBetweenThem() throws {
        // Quiet for the first and third second, a roar in the second.
        let buffer = try bed(envelope: [0.1, 0.8, 0.1])
        let lines = [line(1, at: 0.1, for: 0.8), line(2, at: 2.1, for: 0.8)]

        let level = try #require(DubBackingBalance.bedLevel(of: buffer, under: lines))

        #expect(abs(level - rms(0.1)) < 0.005, "the roar between the lines did not count")
    }

    /// One line under a hit does not drag the whole scene's bed down.
    @Test func theLevelUnderTheLinesIsAMedian() throws {
        let buffer = try bed(envelope: [0.1, 0.1, 0.8, 0.1, 0.1])
        let lines = (0..<5).map { line($0 + 1, at: Double($0) + 0.1, for: 0.8) }

        let level = try #require(DubBackingBalance.bedLevel(of: buffer, under: lines))

        #expect(abs(level - rms(0.1)) < 0.005)
    }

    @Test func aLineOutsideTheBedIsIgnored() throws {
        let buffer = try bed(envelope: [0.3])
        let lines = [line(1, at: 0.1, for: 0.8), line(2, at: 10, for: 1)]

        let level = try #require(DubBackingBalance.bedLevel(of: buffer, under: lines))

        #expect(abs(level - rms(0.3)) < 0.005)
    }

    @Test func aBedWithNoLinesOverItHasNoLevel() throws {
        #expect(DubBackingBalance.bedLevel(of: try bed(envelope: [0.3]), under: []) == nil)
        #expect(DubBackingBalance.bedLevel(of: try bed(envelope: [0.3]), under: [line(1, at: 5, for: 1)]) == nil)
    }

    /// The property the whole design turns on, and the one a future duck or ride would break:
    /// one gain, for the scene, whatever the dialogue is doing at the time.
    ///
    /// There is deliberately no per-moment API to test here. A scene's bed is a number, not a
    /// curve, and if this file ever grows a `gain(at:)` it should be because somebody decided
    /// to bring ducking back on purpose.
    @Test func theBedIsOneNumberForTheWholeScene() {
        let first = DubBackingBalance.bedGain(bed: 0.3, dialogue: 0.25)
        let second = DubBackingBalance.bedGain(bed: 0.3, dialogue: 0.25)

        #expect(first == second)
        #expect(first > 0)
    }
}
