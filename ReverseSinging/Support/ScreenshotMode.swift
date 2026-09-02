//
//  ScreenshotMode.swift
//  ReverseSinging
//
//  Poses the app for App Store screenshots and the app preview recording.
//
//  Every symbol here is behind `#if DEBUG`, so none of it exists in a shipping
//  build. It is driven entirely from the launch-argument domain by
//  `Local/Tools/screenshots/capture.sh`, see that script for the flags.
//

#if DEBUG

import AVFoundation
import Foundation

/// One screen the capture script can ask for. The raw values must stay in sync with
/// `SCREENS_ALL` in `Local/Tools/screenshots/capture.sh` and with the keys in `captions.json`.
enum ScreenshotDestination: String {
    case home
    case dubLibrary
    case dubDetail
    case dubRecord
    case dubExport
    case reverse
    case settings
    /// The scripted walkthrough recorded as the App Store app preview video.
    case tour

    /// Everything from the library downwards is reached by pushing the dub game.
    var opensDubGame: Bool {
        switch self {
        case .dubLibrary, .dubDetail, .dubRecord, .dubExport, .tour: return true
        case .home, .reverse, .settings: return false
        }
    }

    /// Deeper than the library: the first pack has to be selected too.
    var opensPack: Bool {
        switch self {
        case .dubDetail, .dubRecord, .dubExport, .tour: return true
        default: return false
        }
    }

    var opensRecorder: Bool { self == .dubRecord }
    var posesExport: Bool { self == .dubExport }
    var opensReverseGame: Bool { self == .reverse }
    var opensSettings: Bool { self == .settings }
    var isTour: Bool { self == .tour }
}

enum ScreenshotMode {

    // MARK: - Flags

    /// `nonisolated` so the reporters that gate on it can be called from any thread.
    nonisolated static var isActive: Bool {
        UserDefaults.standard.bool(forKey: "screenshotMode")
    }

    static var destination: ScreenshotDestination? {
        UserDefaults.standard.string(forKey: "screenshotDestination")
            .flatMap(ScreenshotDestination.init(rawValue:))
    }

    // MARK: - Pose

    /// The line the recorder opens on. Third of the scene: far enough in that the
    /// progress bar has something to show, early enough that the list above it isn't
    /// scrolled out of its own header.
    static let posedLineIndex = 2

    /// How many lines are already dubbed. Reads as a session in progress rather than
    /// an untouched pack or a finished one.
    static let posedTakeCount = 7

    static let posedExportProgress: Double = 0.7

    // MARK: - Seeding

    /// Writes takes for the first `posedTakeCount` lines so the progress bar, the slate
    /// and the "Play My Dub" action all have something real behind them, and so the
    /// record screen can draw a take over the reference.
    ///
    /// Idempotent: a take that already exists is left alone, which keeps a second launch
    /// in the same simulator from re-doing the work.
    static func seedTakes(for pack: DubPack) {
        for (offset, line) in pack.lines.prefix(posedTakeCount).enumerated() {
            let destination = pack.takeURL(for: line)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try? writeTake(from: pack.referenceAudioURL(for: line), to: destination)
            }
            DubScoreStore.shared.save(score(for: line, offset: offset), forPackID: pack.id)
        }
    }

    /// Scores to sit beside the seeded takes. A pack showing "7 dubbed" and "0 scored"
    /// reads as a bug in a screenshot, so the two are seeded together.
    ///
    /// Spread rather than uniform, and deliberately short of perfect: a column of 90s
    /// looks generated, and a screenshot claiming a flawless scene sets an expectation
    /// the first real take will not meet.
    private static func score(for line: DubLine, offset: Int) -> DubLineScore {
        let timings: [Double] = [88, 71, 94, 66, 82, 77, 90]
        let pacings: [Double] = [81, 79, 88, 74, 86, 69, 85]
        let deliveries: [Double] = [76, 84, 80, 71, 78, 83, 87]
        let index = offset % timings.count
        return DubLineScore(
            slug: line.slug,
            timing: timings[index],
            pacing: pacings[index],
            delivery: deliveries[index]
        )
    }

    // MARK: - App Preview

    /// The beat sheet for the App Store app preview.
    ///
    /// Apple takes previews between 15 and 30 seconds. These add up to about 28, which
    /// leaves room for the launch and the first navigation push without risking the
    /// ceiling. A preview one frame over is rejected outright, and the trim happens in
    /// App Store Connect where it can't be scripted.
    enum Tour {
        static let libraryHold: TimeInterval = 3.0
        static let detailHold: TimeInterval = 3.0
        static let recorderOpen: TimeInterval = 1.6
        static let listen: TimeInterval = 3.2
        static let playTake: TimeInterval = 3.2
        static let lineStep: TimeInterval = 1.5
        static let backToDetail: TimeInterval = 1.4
        static let playback: TimeInterval = 4.4
        static let beforeExport: TimeInterval = 0.8
        static let exportRamp: TimeInterval = 4.0
        static let tail: TimeInterval = 1.2

        /// What the recorder should run for, plus a margin for the cold launch and the
        /// push into the library. `record.sh` reads this from its own copy of the number,
        /// they are kept in step by hand, and the script trims to 29s regardless.
        static var total: TimeInterval {
            libraryHold + detailHold + recorderOpen + listen + playTake
                + lineStep * 2 + backToDetail + playback + beforeExport + exportRamp + tail
        }
    }

    // MARK: - Reverse Singing

    /// The score the posed reverse session comes out with. High enough to look like a
    /// good run, short of the perfect-match band so the screenshot isn't a promise.
    static let posedSimilarityScore: Double = 84

    /// Puts a finished reverse-singing session in front of the camera.
    ///
    /// Without it the screen is one enabled button and two greyed rows: technically the
    /// app, but it shows nothing of the game. Four takes and a score turn it into the
    /// screen a player actually sits in front of.
    static func seedReverseSession(into appState: inout AppState) {
        let directory = AudioFileManager.shared.recordingsDirectory()

        func recording(_ name: String, type: Recording.RecordingType, reversed: Bool) -> Recording? {
            let url = directory.appendingPathComponent("screenshot-\(name).caf")
            if !FileManager.default.fileExists(atPath: url.path) {
                guard (try? writeSungPhrase(to: url, reversed: reversed)) != nil else { return nil }
            }
            return Recording(url: url, duration: sungPhraseDuration, type: type)
        }

        var session = AudioSession(name: "Take 01")
        let takes: [(String, Recording.RecordingType, Bool)] = [
            ("original", .original, false),
            ("reversed", .reversed, true),
            ("attempt", .attempt, true),
            ("reversed-attempt", .reversedAttempt, false),
        ]
        for (name, type, reversed) in takes {
            if let take = recording(name, type: type, reversed: reversed) {
                session.addRecording(take)
            }
        }

        appState.currentSession = session
        appState.similarityScore = posedSimilarityScore
        appState.attemptCount = 1
        appState.isScoreVisible = true
    }

    static let sungPhraseDuration: TimeInterval = 4.2

    /// A short sung phrase, five held notes with vibrato, over a decaying envelope.
    ///
    /// The reverse game's own audio, not a dialogue chunk borrowed from the dub pack: the
    /// waveform is the thing on screen, and a spoken shape under "sing a song backwards"
    /// would be the wrong picture.
    private static func writeSungPhrase(to destination: URL, reversed: Bool) throws {
        let sampleRate = 44100.0
        let frames = Int(sungPhraseDuration * sampleRate)
        // A minor-pentatonic rise and fall, so the phrase reads as a tune rather than a scale.
        let notes: [Double] = [220.0, 261.63, 293.66, 261.63, 196.0]
        let noteFrames = frames / notes.count

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(frames)

        for frame in 0..<frames {
            let index = min(notes.count - 1, frame / noteFrames)
            let inNote = Double(frame - index * noteFrames) / Double(noteFrames)
            let time = Double(frame) / sampleRate

            // Vibrato, and a gentle attack/release per note so the bars aren't a solid block.
            let pitch = notes[index] * (1 + 0.012 * sin(2 * .pi * 5.5 * time))
            let envelope = sin(min(1, inNote * 1.05) * .pi) * (1 - 0.25 * Double(index) / Double(notes.count))

            var value = sin(2 * .pi * pitch * time) * 0.6
            value += sin(4 * .pi * pitch * time) * 0.22      // second harmonic, for a voiced timbre
            value += sin(6 * .pi * pitch * time) * 0.09
            samples[frame] = Float(value * envelope * 0.5)
        }

        if reversed {
            var head = 0
            var tail = frames - 1
            while head < tail {
                (samples[head], samples[tail]) = (samples[tail], samples[head])
                head += 1
                tail -= 1
            }
        }

        let file = try AVAudioFile(
            forWriting: destination,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        try file.write(from: buffer)
    }

    /// Derives a plausible take from the reference: the same words at the same length,
    /// nudged late and unevenly loud, the way a real attempt sits against the original.
    /// The point is the *shape*. The record screen draws both waveforms on one axis, and
    /// two identical shapes would look like a bug rather than a performance.
    private static func writeTake(from source: URL, to destination: URL) throws {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let frameCount = AVAudioFrameCount(input.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        try input.read(into: buffer)
        buffer.frameLength = frameCount

        let sampleRate = format.sampleRate
        let lateBy = Int(0.06 * sampleRate)          // came in a beat late
        let frames = Int(frameCount)

        for channel in 0..<Int(format.channelCount) {
            guard let samples = buffer.floatChannelData?[channel] else { continue }
            let original = Array(UnsafeBufferPointer(start: samples, count: frames))
            for frame in 0..<frames {
                let sourceFrame = frame - lateBy
                let value = sourceFrame >= 0 ? original[sourceFrame] : 0
                // A slow swell across the line: louder in the middle, softer at the edges.
                let position = Double(frame) / Double(max(1, frames))
                let gain = Float(0.72 + 0.5 * sin(position * .pi))
                samples[frame] = value * gain
            }
        }

        let output = try AVAudioFile(
            forWriting: destination,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        try output.write(from: buffer)
    }
}

#endif
