//
//  DubMixerTests.swift
//  ReverseSingingTests
//
//  Takes land on the timeline where their timestamps say they should
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

@Suite("Dub Audio Mixing")
struct DubMixerTests {

    /// Builds a pack whose lines carry a loud tone as the user's take, so the mixed output
    /// can be checked for energy at exactly the timestamps the pack declares.
    private func makeTonePack(
        timestamps: [TimeInterval],
        toneDuration: TimeInterval = 0.5,
        takeAmplitudes: [Float]? = nil,
        referenceLeadIns: [TimeInterval]? = nil,
        measureSpeechWindows: Bool = false
    ) throws -> (DubPack, URL) {
        // Inside the real packs directory, not a temp one: `DubPack.referenceAudioURL` resolves
        // against it, so a fixture written anywhere else has reference audio the mixer cannot
        // open. Torn down by `deleteDubPack` in each test's defer.
        let directory = AudioFileManager.shared.dubPacksDirectory()
            .appendingPathComponent("dubmix-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let packID = UUID()
        let takesDirectory = AudioFileManager.shared.dubTakesDirectory(packID: packID)

        var lines: [DubLine] = []

        for (offset, timestamp) in timestamps.enumerated() {
            let slug = String(format: "%03d_Tester", offset + 1)

            // Reference audio the parser would have measured. A lead-in makes it a slice of
            // a scene rather than an isolated line, which is what real packs ship.
            let referenceURL = directory.appendingPathComponent("\(slug).wav")
            let lead = referenceLeadIns?[offset] ?? 0
            try writeTone(
                to: referenceURL,
                duration: toneDuration,
                amplitude: lead > 0 ? 0.6 : 0,
                leadIn: lead
            )

            // The user's take: full-scale tone, so it's unmistakable in the mix
            try writeTone(
                to: takesDirectory.appendingPathComponent("\(slug).caf"),
                duration: toneDuration,
                amplitude: takeAmplitudes?[offset] ?? 0.9
            )

            lines.append(DubLine(
                index: offset + 1,
                slug: slug,
                character: "Tester",
                caption: "line \(offset + 1)",
                imageFile: "\(slug).jpg",
                referenceAudioFile: "\(slug).wav",
                startTime: timestamp,
                duration: toneDuration,
                // What the parser records at import. Left nil by default so the fixtures also
                // cover a pack that predates the measurement.
                speech: measureSpeechWindows
                    ? DubSpeechWindow(start: lead, end: toneDuration)
                    : nil
            ))
        }

        let pack = DubPack(
            id: packID,
            title: "Tone Pack",
            authors: [],
            iconFile: "001_Tester.jpg",
            backingTrackFile: nil,
            folderName: directory.lastPathComponent,
            lines: lines,
            duration: (timestamps.max() ?? 0) + toneDuration + 1
        )

        return (pack, directory)
    }

    private func writeTone(
        to url: URL,
        duration: TimeInterval,
        amplitude: Float,
        leadIn: TimeInterval = 0
    ) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        )!

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        let silentFrames = Int(leadIn * format.sampleRate)
        for frame in 0..<Int(frameCount) {
            samples[frame] = frame < silentFrames
                ? 0
                : amplitude * sinf(2 * .pi * 440 * Float(frame - silentFrames) / Float(format.sampleRate))
        }

        try file.write(from: buffer)
    }

    /// Peak absolute sample in a one-second window starting at `second`.
    private func peak(of url: URL, atSecond second: Int) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate

        let startFrame = AVAudioFramePosition(Double(second) * sampleRate)
        guard startFrame < file.length else { return 0 }

        file.framePosition = startFrame

        let framesToRead = AVAudioFrameCount(min(Int64(sampleRate), file.length - startFrame))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead)!
        try file.read(into: buffer, frameCount: framesToRead)

        var maximum: Float = 0
        for channel in 0..<Int(format.channelCount) {
            let samples = buffer.floatChannelData![channel]
            for frame in 0..<Int(buffer.frameLength) {
                maximum = max(maximum, abs(samples[frame]))
            }
        }

        return maximum
    }

    @Test func placesEachTakeAtItsTimestamp() async throws {
        let (pack, directory) = try makeTonePack(timestamps: [1.0, 5.0])
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        let outputURL = directory.appendingPathComponent("mix.m4a")
        try await DubMixer.shared.mixAudio(pack: pack, to: outputURL)

        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // Loud where the takes were placed
        #expect(try peak(of: outputURL, atSecond: 1) > 0.3)
        #expect(try peak(of: outputURL, atSecond: 5) > 0.3)

        // Quiet in the gaps between them
        #expect(try peak(of: outputURL, atSecond: 3) < 0.05)
    }

    @Test func mixesEveryRecordedLine() async throws {
        let (pack, directory) = try makeTonePack(timestamps: [0.5, 2.5, 4.5, 6.5])
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        #expect(DubMixer.shared.recordedLines(in: pack).count == 4)

        let outputURL = directory.appendingPathComponent("mix.m4a")
        try await DubMixer.shared.mixAudio(pack: pack, to: outputURL)

        for second in [0, 2, 4, 6] {
            #expect(try peak(of: outputURL, atSecond: second) > 0.3, "expected a take around \(second)s")
        }
    }

    /// Two characters talking over each other have to be heard over each other.
    ///
    /// Both lines are two seconds of the same tone, one from 0s and one from 1s, so the middle
    /// second carries both. What is being checked is that the overlap is *louder* than either
    /// line alone: put on a single `AVAudioPlayerNode` the two are not summed — the node keeps
    /// the start times but only one of them is audible through the overlap, so this second
    /// would come out at the same level as the ones either side of it and half the
    /// interruption would be silently missing.
    @Test func overlappingLinesAreSummedRatherThanOneWinning() async throws {
        let (pack, directory) = try makeTonePack(
            timestamps: [0.0, 1.0],
            toneDuration: 2.0,
            takeAmplitudes: [0.4, 0.4]
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        let outputURL = directory.appendingPathComponent("mix.m4a")
        try await DubMixer.shared.mixAudio(pack: pack, to: outputURL)

        let firstAlone = try peak(of: outputURL, atSecond: 0)
        let together = try peak(of: outputURL, atSecond: 1)
        let secondAlone = try peak(of: outputURL, atSecond: 2)

        #expect(firstAlone > 0.1)
        #expect(secondAlone > 0.1)
        #expect(together > firstAlone * 1.5, "overlap \(together) vs one voice \(firstAlone)")
    }

    /// Three loud takes stacked on the same moment sum to well past full scale. Without a
    /// limiter on the way out the encoder squares off the tops of that and the export
    /// distorts — the cost of summing overlapping lines rather than dropping one of them.
    @Test func stackedTakesDoNotClipTheExport() async throws {
        let (pack, directory) = try makeTonePack(
            timestamps: [0.0, 0.0, 0.0],
            toneDuration: 2.0,
            takeAmplitudes: [0.6, 0.6, 0.6]
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        let outputURL = directory.appendingPathComponent("mix.m4a")
        try await DubMixer.shared.mixAudio(pack: pack, to: outputURL)

        let loudest = try peak(of: outputURL, atSecond: 0)

        // Held below full scale rather than flattened against it
        #expect(loudest < 0.99, "peaked at \(loudest)")

        // And still a mix, not something the limiter crushed into nothing
        #expect(loudest > 0.5, "peaked at \(loudest)")
    }

    /// A pack's timestamp is where the audio chunk starts, not where the character speaks. Here
    /// the reference opens with a second of room tone, so a take dropped at the raw timestamp
    /// would land a second before the mouth moves — which is what made a dub feel out of step
    /// on some lines and not others, since the run-up differs on every line.
    @Test func aTakeIsPlacedWhereTheOriginalSpeaks() async throws {
        let (pack, directory) = try makeTonePack(
            timestamps: [2.0],
            toneDuration: 2.0,
            takeAmplitudes: [0.7],
            referenceLeadIns: [1.0]
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        let outputURL = directory.appendingPathComponent("mix.m4a")
        try await DubMixer.shared.mixAudio(pack: pack, to: outputURL)

        // Quiet through the original's run-up, 2.0–3.0s
        #expect(try peak(of: outputURL, atSecond: 2) < 0.05)

        // Speaking from 3.0s, where the original does
        #expect(try peak(of: outputURL, atSecond: 3) > 0.3)
    }

    /// The same thing again, but on a pack the parser has already measured — which is what
    /// every real pack looks like. The stored window is what places the take; nothing goes
    /// back to the reference file to work it out a second time.
    @Test func aMeasuredLinePlacesItsTakeFromTheStoredWindow() async throws {
        let (pack, directory) = try makeTonePack(
            timestamps: [2.0],
            toneDuration: 2.0,
            takeAmplitudes: [0.7],
            referenceLeadIns: [1.0],
            measureSpeechWindows: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        #expect(pack.hasMeasuredSpeech)
        #expect(abs(pack.lines[0].speechStartTime - 3.0) < 0.001)

        let outputURL = directory.appendingPathComponent("mix.m4a")
        try await DubMixer.shared.mixAudio(pack: pack, to: outputURL)

        #expect(try peak(of: outputURL, atSecond: 2) < 0.05, "quiet through the original's run-up")
        #expect(try peak(of: outputURL, atSecond: 3) > 0.3, "speaking where the original does")
    }

    @Test func refusesToExportWithNoTakes() async throws {
        let (pack, directory) = try makeTonePack(timestamps: [1.0])
        defer { try? FileManager.default.removeItem(at: directory) }

        // Drop the takes the fixture wrote
        try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)

        #expect(DubMixer.shared.recordedLines(in: pack).isEmpty)

        await #expect(throws: DubExportError.self) {
            _ = try await DubMixer.shared.export(pack: pack)
        }
    }
}
