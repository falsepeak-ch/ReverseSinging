//
//  DubOverlapExportTests.swift
//  ReverseSingingTests
//
//  Two actors speaking at once, recorded apart, exported together
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

/// Checks the export against the geometry of a real scene rather than a convenient one.
///
/// The timestamps, clip lengths and run-up silences below are measured from real packs. Each
/// character's take is a tone at its own frequency, so the exported file can be asked a
/// question a peak meter cannot answer: not "is something loud here" but "are both of these
/// voices present in this instant".
@Suite("Dub Overlap Export")
struct DubOverlapExportTests {

    struct RealLine {
        let slug: String
        let character: String
        let start: TimeInterval
        let length: TimeInterval
        /// Silence at the head of the reference clip, before the character speaks.
        let lead: TimeInterval
        /// The tone standing in for this character's voice.
        let frequency: Float

        init(
            slug: String,
            character: String,
            start: TimeInterval,
            length: TimeInterval,
            lead: TimeInterval,
            frequency: Float
        ) {
            self.slug = slug
            self.character = character
            self.start = start
            self.length = length
            self.lead = lead
            self.frequency = frequency
        }
    }

    static let dobby: Float = 440
    static let harry: Float = 1200

    /// Measured from a pack, not invented: the four places in the Dobby scene where two
    /// characters talk over each other.
    static let dobbyScene: [RealLine] = [
        RealLine(slug: "016_Dobby", character: "Dobby", start: 68.611, length: 4.568, lead: 0.000, frequency: dobby),
        RealLine(slug: "017_Harry", character: "Harry", start: 69.990, length: 4.447, lead: 0.000, frequency: harry),
        RealLine(slug: "019_Dobby", character: "Dobby", start: 82.787, length: 5.670, lead: 0.000, frequency: dobby),
        RealLine(slug: "020_Harry", character: "Harry", start: 83.843, length: 2.870, lead: 0.140, frequency: harry),
        RealLine(slug: "029_Dobby", character: "Dobby", start: 130.000, length: 9.462, lead: 0.400, frequency: dobby),
        RealLine(slug: "030_Harry", character: "Harry", start: 134.210, length: 3.800, lead: 0.160, frequency: harry),
        RealLine(slug: "046_Dobby", character: "Dobby", start: 184.476, length: 7.739, lead: 0.020, frequency: dobby),
        RealLine(slug: "047_Harry", character: "Harry", start: 184.509, length: 8.070, lead: 0.000, frequency: harry)
    ]

    /// A second real pack, which fails differently: almost no reference run-up silence, but
    /// five short overlaps. The middle and final groups are chains: the centre line overlaps
    /// both its neighbours. The old fixture only represented three disjoint pairs and silently
    /// omitted two of the five boundaries.
    static let lotrScene: [RealLine] = [
        RealLine(slug: "001_Gandalf", character: "Gandalf", start: 3.745, length: 3.000, lead: 0.00, frequency: dobby),
        RealLine(slug: "002_Frodo", character: "Frodo", start: 6.305, length: 2.848688, lead: 0.00, frequency: harry),
        RealLine(slug: "010_Boromir", character: "Boromir", start: 73.47, length: 3.00, lead: 0.00, frequency: dobby),
        RealLine(slug: "011_Frodo", character: "Frodo", start: 75.00, length: 3.41, lead: 0.00, frequency: harry),
        RealLine(slug: "012_Gandalf", character: "Gandalf", start: 77.58, length: 4.34, lead: 0.00, frequency: dobby),
        RealLine(slug: "015_Frodo", character: "Frodo", start: 97.01, length: 2.97, lead: 0.00, frequency: harry),
        RealLine(slug: "016_Boromir", character: "Boromir", start: 99.66, length: 4.49, lead: 0.00, frequency: dobby),
        RealLine(slug: "017_Frodo", character: "Frodo", start: 103.27, length: 3.89, lead: 0.00, frequency: harry)
    ]

    /// The pack's declared edit interval. Waveform analysis must not rewrite this geometry.
    private func placement(_ line: RealLine) -> ClosedRange<TimeInterval> {
        line.start...(line.start + line.length)
    }

    // MARK: - Fixture

    private func makeScenePack(_ scene: [RealLine]) throws -> DubPack {
        let packID = UUID()
        let folder = "dubovl-\(UUID().uuidString)"
        let directory = AudioFileManager.shared.dubPacksDirectory()
            .appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let takes = AudioFileManager.shared.dubTakesDirectory(packID: packID)
        var lines: [DubLine] = []

        for (index, line) in scene.enumerated() {
            // The reference: the character's tone, behind the real run-up of silence.
            try writeTone(
                to: directory.appendingPathComponent("\(line.slug).wav"),
                duration: line.length,
                frequency: line.frequency,
                leadIn: line.lead
            )

            // Immediate test signal: this suite proves that the mixer preserves declared
            // overlaps. Separate placement tests prove that real take buffers are not cut.
            try writeTone(
                to: takes.appendingPathComponent("\(line.slug).caf"),
                duration: line.length,
                frequency: line.frequency,
                leadIn: 0
            )

            lines.append(DubLine(
                index: index + 1,
                slug: line.slug,
                character: line.character,
                caption: line.slug,
                imageFile: "\(line.slug).jpg",
                referenceAudioFile: "\(line.slug).wav",
                startTime: line.start,
                duration: line.length
            ))
        }

        return DubPack(
            id: packID,
            title: "Overlap Scene",
            authors: [],
            iconFile: "\(scene[0].slug).jpg",
            backingTrackFile: nil,
            folderName: folder,
            lines: lines,
            duration: (scene.map { $0.start + $0.length }.max() ?? 0) + 1
        )
    }

    private func writeTone(
        to url: URL,
        duration: TimeInterval,
        frequency: Float,
        leadIn: TimeInterval
    ) throws {
        let format = DubAudioLoader.canonicalFormat
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frames = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        let silent = Int(leadIn * format.sampleRate)
        for frame in 0..<Int(frames) {
            samples[frame] = frame < silent
                ? 0
                : 0.45 * sinf(2 * .pi * frequency * Float(frame - silent) / Float(format.sampleRate))
        }

        try file.write(from: buffer)
    }

    // MARK: - Measurement

    private func samples(of url: URL, at time: TimeInterval, window: TimeInterval) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat

        let start = AVAudioFramePosition(time * format.sampleRate)
        guard start >= 0, start < file.length else { return [] }
        file.framePosition = start

        let count = AVAudioFrameCount(min(Int64(window * format.sampleRate), file.length - start))
        guard count > 0 else { return [] }

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        try file.read(into: buffer, frameCount: count)

        let channel = buffer.floatChannelData![0]
        return (0..<Int(buffer.frameLength)).map { channel[$0] }
    }

    /// Goertzel: how much of one frequency is in this stretch of audio. Enough to answer
    /// "is this voice here", without pulling in a whole FFT.
    private func strength(of frequency: Float, in samples: [Float], sampleRate: Double = 44_100) -> Double {
        guard samples.count > 1 else { return 0 }

        let bin = (Double(samples.count) * Double(frequency) / sampleRate).rounded()
        let omega = 2 * Double.pi * bin / Double(samples.count)
        let coefficient = 2 * cos(omega)

        var previous = 0.0
        var beforeThat = 0.0

        for sample in samples {
            let current = Double(sample) + coefficient * previous - beforeThat
            beforeThat = previous
            previous = current
        }

        let power = previous * previous + beforeThat * beforeThat - coefficient * previous * beforeThat
        return max(0, power).squareRoot() / Double(samples.count)
    }

    // MARK: - Tests

    /// The question itself: in the exported file, at the moment both characters are speaking,
    /// are both of them actually there?
    @Test(arguments: [("Dobby", dobbyScene), ("LOTR", lotrScene)])
    func bothVoicesArePresentAtOnceInTheExport(named: String, scene: [RealLine]) async throws {
        let pack = try makeScenePack(scene)
        defer {
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        let outputURL = AudioFileManager.shared.dubPacksDirectory()
            .appendingPathComponent("overlap-\(pack.id).m4a")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try await DubMixer.shared.mixAudio(pack: pack, to: outputURL)

        var overlapsChecked = 0
        for firstIndex in scene.indices {
            for secondIndex in scene.indices where secondIndex > firstIndex {
                let first = scene[firstIndex]
                let second = scene[secondIndex]

                let a = placement(first)
                let b = placement(second)
                let overlapStart = max(a.lowerBound, b.lowerBound)
                let overlapEnd = min(a.upperBound, b.upperBound)
                guard overlapEnd > overlapStart else { continue }
                overlapsChecked += 1

                // Well inside the overlap, away from either edge
                let probe = (overlapStart + overlapEnd) / 2
                let heard = try samples(of: outputURL, at: probe, window: min(0.2, overlapEnd - probe))

                let dobby = strength(of: Self.dobby, in: heard)
                let harry = strength(of: Self.harry, in: heard)

                #expect(
                    dobby > 0.02 && harry > 0.02,
                    "\(named): \(first.slug)/\(second.slug) at \(String(format: "%.2f", probe))s — \(dobby) / \(harry)"
                )
            }
        }

        #expect(overlapsChecked == (named == "LOTR" ? 5 : 4),
                "\(named): fixture checked \(overlapsChecked) overlap boundaries")
    }

    /// The exact first LOTR boundary reported in the attached pack: Gandalf's three-second
    /// "You cannot pass!" starts at 3.745 and Frodo's "Gandalf!" starts at 6.305.
    @Test func gandalfAndFrodoKeepThePacksExactOverlap() {
        let gandalf = placement(Self.lotrScene[0])
        let frodo = placement(Self.lotrScene[1])
        let overlap = min(gandalf.upperBound, frodo.upperBound)
            - max(gandalf.lowerBound, frodo.lowerBound)

        #expect(abs(overlap - 0.440) < 0.000_001, "overlap was \(overlap)s")
        #expect(DubVoiceLanes.assign(
            Array(Self.lotrScene.prefix(2)),
            start: { placement($0).lowerBound },
            end: { placement($0).upperBound }
        ).count == 2, "the two voices must be scheduled on independent playback nodes")
    }

    /// The other half of the claim: where only one of them is speaking, only one of them is
    /// there. Without this, a test that finds both frequencies everywhere would still pass.
    @Test func onlyOneVoiceIsPresentOutsideTheOverlap() async throws {
        let pack = try makeScenePack(Self.dobbyScene)
        defer {
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        }

        let outputURL = AudioFileManager.shared.dubPacksDirectory()
            .appendingPathComponent("solo-\(pack.id).m4a")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try await DubMixer.shared.mixAudio(pack: pack, to: outputURL)

        // 019_Dobby speaks from 82.787; Harry doesn't join until 83.983.
        let heard = try samples(of: outputURL, at: 83.2, window: 0.25)

        let dobby = strength(of: Self.dobby, in: heard)
        let harry = strength(of: Self.harry, in: heard)

        #expect(dobby > 0.02, "Dobby should be speaking alone here, got \(dobby)")
        #expect(harry < dobby / 4, "Harry should not be here yet — Dobby \(dobby), Harry \(harry)")
    }
}
