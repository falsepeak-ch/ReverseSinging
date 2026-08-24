//
//  DubSpeechWindowTests.swift
//  ReverseSingingTests
//
//  The one measurement everything else times itself against
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

@Suite("Dub Speech Windows")
struct DubSpeechWindowTests {

    // MARK: - Onset Windows

    private func clip(silence: TimeInterval, tone: TimeInterval, trailing: TimeInterval) -> AVAudioPCMBuffer {
        let format = DubAudioLoader.canonicalFormat
        let total = silence + tone + trailing
        let frames = AVAudioFrameCount(total * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        let start = Int(silence * format.sampleRate)
        let end = start + Int(tone * format.sampleRate)

        for frame in 0..<Int(frames) {
            samples[frame] = (frame >= start && frame < end)
                ? 0.6 * sinf(2 * .pi * 440 * Float(frame) / Float(format.sampleRate))
                : 0
        }
        return buffer
    }

    @Test func aWindowFindsBothEdgesOfTheSpeech() throws {
        let window = try #require(DubSpeechOnset.window(of: clip(silence: 0.5, tone: 1.2, trailing: 0.8)))

        #expect(abs(window.start - 0.5) < 0.05, "start was \(window.start)")
        #expect(abs(window.end - 1.7) < 0.05, "end was \(window.end)")
    }

    @Test func aWindowNeverClosesBeforeItOpens() throws {
        let window = try #require(DubSpeechOnset.window(of: clip(silence: 1.0, tone: 0.05, trailing: 1.0)))
        #expect(window.end >= window.start)
        #expect(window.duration >= 0)
    }

    @Test func silenceHasNoWindow() {
        #expect(DubSpeechOnset.window(of: clip(silence: 2, tone: 0, trailing: 0)) == nil)
    }

    /// `leadIn` is what places a take, and it still has to behave exactly as it did before the
    /// window existed — the two are now one measurement, which is the point.
    @Test func leadInStillAgreesWithTheWindowStart() throws {
        let buffer = clip(silence: 0.75, tone: 1.0, trailing: 0.5)
        let window = try #require(DubSpeechOnset.window(of: buffer))

        #expect(abs(DubSpeechOnset.leadIn(of: buffer) - window.start) < 0.001)
    }

    // MARK: - Alignment

    /// The behaviour the whole feature rests on: a take is dropped where the character speaks,
    /// not where the chunk begins.
    @Test func aTakeIsPlacedOnTheOriginalsFirstWord() {
        let line = DubLine(
            index: 1,
            slug: "001_Tester",
            character: "Tester",
            caption: "Line",
            imageFile: "still.jpg",
            referenceAudioFile: "line.wav",
            startTime: 30,
            duration: 3,
            speech: DubSpeechWindow(start: 1.4, end: 2.6)
        )

        // A take with its own half-second of hesitation on the front.
        let take = clip(silence: 0.5, tone: 1.0, trailing: 1.5)
        let placement = DubVoiceAlignment.place(take: take, for: line)

        #expect(abs(placement.startTime - 31.4) < 0.001,
                "placed at \(placement.startTime), should be the original's first word")

        // Both vocal edges are fitted: the take's one-second utterance occupies the original
        // actor's 1.2-second speech window, preserving every interruption at the far edge.
        let fitted = Double(placement.buffer.frameLength) / DubAudioLoader.canonicalFormat.sampleRate
        #expect(abs(fitted - 1.2) < 0.01, "take is \(fitted)s after fitting, expected 1.2")

        let fittedSpeech = DubSpeechOnset.window(of: placement.buffer)
        #expect((fittedSpeech?.start ?? 1) < 0.05, "fitted speech must open on the first-word edge")
        #expect((fittedSpeech?.end ?? 0) > 1.15, "fitted speech must reach the last-word edge")
    }

    /// A reference is left exactly where it was cut from — shifting the original against
    /// itself would only slide the scene off its own backing track.
    @Test func aReferenceIsPlacedAtItsChunkTimestamp() {
        let line = DubLine(
            index: 1,
            slug: "001_Tester",
            character: "Tester",
            caption: "Line",
            imageFile: "still.jpg",
            referenceAudioFile: "line.wav",
            startTime: 30,
            duration: 3,
            speech: DubSpeechWindow(start: 1.4, end: 2.6)
        )

        let placement = DubVoiceAlignment.placeReference(clip(silence: 1.4, tone: 1.2, trailing: 0.4), for: line)
        #expect(placement.startTime == 30)
    }

    /// A take that already opens on speech still gets its far edge fitted to the actor.
    @Test func aTakeWithNoRunUpStillMatchesTheOriginalsLastWord() {
        let line = DubLine(
            index: 1, slug: "001_Tester", character: "Tester", caption: "Line",
            imageFile: "still.jpg", referenceAudioFile: "line.wav",
            startTime: 5, duration: 2, speech: DubSpeechWindow(start: 0.2, end: 1.8)
        )

        let take = clip(silence: 0, tone: 1.5, trailing: 0.5)
        let placement = DubVoiceAlignment.place(take: take, for: line)

        let fitted = Double(placement.buffer.frameLength) / DubAudioLoader.canonicalFormat.sampleRate
        #expect(abs(fitted - 1.6) < 0.01)
        #expect(abs(placement.startTime - 5.2) < 0.001)
    }

    /// Action scenes can leave music or an effect in the measured reference window. A bad
    /// far edge must not stretch a short shout into an obviously artificial drawl.
    @Test func anExtremeReferenceTailDoesNotRewriteThePerformance() {
        let line = DubLine(
            index: 1, slug: "001_Tester", character: "Tester", caption: "No!",
            imageFile: "still.jpg", referenceAudioFile: "line.wav",
            startTime: 5, duration: 3, speech: DubSpeechWindow(start: 0, end: 3)
        )

        let take = clip(silence: 0.2, tone: 0.8, trailing: 2.0)
        let placement = DubVoiceAlignment.place(take: take, for: line)
        let duration = Double(placement.buffer.frameLength) / DubAudioLoader.canonicalFormat.sampleRate

        #expect(abs(duration - 0.8) < 0.05, "extreme fit should be rejected, got \(duration)s")
    }

    // MARK: - Persistence

    /// Windows are measured once and written into the manifest. A pack that has to be
    /// re-measured on every launch is a pack that stutters on every launch.
    @Test func aWindowSurvivesTheManifestRoundTrip() throws {
        let line = DubLine(
            index: 1, slug: "001_Tester", character: "Tester", caption: "Line",
            imageFile: "still.jpg", referenceAudioFile: "line.wav",
            startTime: 12, duration: 3, speech: DubSpeechWindow(start: 0.9, end: 2.4)
        )
        let pack = DubPack(
            title: "Scene", authors: [], iconFile: "still.jpg", backingTrackFile: nil,
            folderName: "scene", lines: [line], duration: 60
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let restored = try decoder.decode(DubPack.self, from: try encoder.encode(pack))

        #expect(restored.lines[0].speech == line.speech)
        #expect(restored.hasMeasuredSpeech)
    }

    /// A manifest written before windows existed still decodes — and reports itself as stale
    /// so the library re-measures it rather than serving chunk timings forever.
    @Test func aManifestWithoutWindowsDecodesAndAsksToBeReparsed() throws {
        let legacy = """
        {
          "id": "\(UUID().uuidString)",
          "title": "Legacy Scene",
          "authors": [],
          "iconFile": "still.jpg",
          "folderName": "legacy",
          "duration": 60,
          "importedAt": "2024-01-01T00:00:00Z",
          "lines": [{
            "id": "\(UUID().uuidString)",
            "index": 1,
            "slug": "001_Tester",
            "character": "Tester",
            "caption": "Line",
            "imageFile": "still.jpg",
            "referenceAudioFile": "line.wav",
            "startTime": 12,
            "duration": 3
          }]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let pack = try decoder.decode(DubPack.self, from: Data(legacy.utf8))

        #expect(pack.lines[0].speech == nil)
        #expect(!pack.hasMeasuredSpeech)
        #expect(DubPackLibrary.manifestIsStale(pack, in: pack.directoryURL),
                "an unmeasured pack must not keep winning on the fast path")
    }

    // MARK: - Score Store

    @Test func scoresRoundTripAndAreForgottenWithTheirTake() {
        let packID = UUID()
        defer { try? AudioFileManager.shared.deleteDubPack(folderName: "no-such-pack", packID: packID) }

        let store = DubScoreStore.shared
        let score = DubLineScore(slug: "001_Tester", timing: 91, pacing: 77, delivery: 64)

        store.save(score, forPackID: packID)
        #expect(store.scores(forPackID: packID)["001_Tester"]?.overall == score.overall)

        store.remove(slug: "001_Tester", forPackID: packID)
        #expect(store.scores(forPackID: packID).isEmpty,
                "a deleted take must not leave its score behind to average in")
    }

    @Test func aPackWithNoScoresFileReadsAsEmptyRatherThanFailing() {
        #expect(DubScoreStore.shared.scores(forPackID: UUID()).isEmpty)
    }
}
