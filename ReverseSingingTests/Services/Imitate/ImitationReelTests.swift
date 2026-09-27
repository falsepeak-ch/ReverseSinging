//
//  ImitationReelTests.swift
//  ReverseSingingTests
//
//  The video's timing, its verdict and confetti, and the file it renders
//

import Testing
import Foundation
import AVFoundation
import DubScoring
@testable import ReverseSinging

@Suite("Imitation Reel") @MainActor
struct ImitationReelTests {

    // MARK: - Timeline

    @Test func actsFollowEachOtherWithoutGaps() {
        let timeline = ImitationReelTimeline(referenceDuration: 1.5, takeDuration: 2)

        #expect(timeline.referenceStart == ImitationReelTimeline.introDuration)
        #expect(timeline.takeStart == timeline.referenceStart + 1.5 + ImitationReelTimeline.gapAfterReference)
        #expect(timeline.revealStart == timeline.takeStart + 2)
        #expect(timeline.total == timeline.revealStart + ImitationReelTimeline.revealDuration)

        guard case .intro = timeline.act(at: 0) else { Issue.record("0 s is the intro"); return }
        guard case .reference(let r) = timeline.act(at: timeline.referenceStart + 0.5), abs(r - 0.5) < 1e-9 else {
            Issue.record("the original starts after the intro"); return
        }
        guard case .take(let t) = timeline.act(at: timeline.takeStart), t == 0 else {
            Issue.record("the take starts on its own start"); return
        }
        guard case .reveal = timeline.act(at: timeline.total - 0.01) else { Issue.record("it ends on the reveal"); return }
    }

    // MARK: - Verdict

    @Test(arguments: DubGrade.allCases)
    func onlyAPassCelebrates(grade: DubGrade) {
        let verdict = ImitationVerdict.forGrade(grade, seed: 3)
        let passes = grade == .perfect || grade == .great || grade == .good
        #expect(verdict.celebrates == passes)
        #expect(!verdict.word.isEmpty)
        #expect(verdict.tint == (grade == .rough ? .poor : grade == .close ? .fair : .good))
    }

    @Test func theSameSeedPicksTheSameWord() {
        #expect(ImitationVerdict.forGrade(.rough, seed: 11) == ImitationVerdict.forGrade(.rough, seed: 11))
    }

    // MARK: - Confetti

    @Test func confettiIsTheSameBurstEveryTime() {
        let size = CGSize(width: 1080, height: 1920)
        let origin = CGPoint(x: 540, y: 960)
        let first = ConfettiSimulation(seed: 42).pieces(at: 0.8, in: size, from: origin)
        let second = ConfettiSimulation(seed: 42).pieces(at: 0.8, in: size, from: origin)

        #expect(!first.isEmpty)
        #expect(first.map(\.position) == second.map(\.position))
        #expect(ConfettiSimulation(seed: 43).pieces(at: 0.8, in: size, from: origin).map(\.position) != first.map(\.position))
    }

    @Test func confettiIsGoneOutsideItsLifetime() {
        let simulation = ConfettiSimulation(seed: 1)
        let size = CGSize(width: 400, height: 800)
        #expect(simulation.pieces(at: -0.1, in: size, from: .zero).isEmpty)
        #expect(simulation.pieces(at: ConfettiSimulation.lifetime + 0.1, in: size, from: .zero).isEmpty)
    }

    // MARK: - Render

    /// The whole export, without booth footage: a vertical H.264 picture, a soundtrack, and
    /// the length the timeline says.
    @Test(.timeLimit(.minutes(2)))
    func rendersAVerticalVideoWithSound() async throws {
        let cat = try #require(ImitationSoundLibrary.sound(id: "cat")?.url)
        let owl = try #require(ImitationSoundLibrary.sound(id: "owl")?.url)
        let score = try #require(ImitationScorer.score(takeURL: owl, referenceURL: cat))

        let reel = ImitationReel(
            soundName: "Cat",
            emoji: "🐱",
            referenceURL: cat,
            takeURL: owl,
            boothURL: nil,
            score: score,
            verdict: ImitationVerdict.forGrade(.great, seed: 0),
            seed: 7,
            artworkName: "imitate-cat"
        )

        let url = try await ImitationReelRenderer.render(reel) { _ in }
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = AVURLAsset(url: url)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await video.load(.naturalSize)
        #expect(size == ImitationReelRenderer.size)
        #expect(try await !asset.loadTracks(withMediaType: .audio).isEmpty)

        let referenceSeconds = try seconds(of: cat)
        let takeSeconds = try seconds(of: owl)
        let expected = ImitationReelTimeline(referenceDuration: referenceSeconds, takeDuration: takeSeconds).total
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - expected) < 0.2)
    }

    /// With booth footage, the attempt's act is the footage, full frame.
    @Test(.timeLimit(.minutes(2)))
    func theAttemptIsTheBoothFootage() async throws {
        let cat = try #require(ImitationSoundLibrary.sound(id: "cat")?.url)
        let owl = try #require(ImitationSoundLibrary.sound(id: "owl")?.url)
        let takeSeconds = try seconds(of: owl)
        let booth = FileManager.default.temporaryDirectory.appendingPathComponent("booth-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: booth) }
        try await writeSolidClip(to: booth, seconds: takeSeconds, green: 200)

        let reel = ImitationReel(
            soundName: "Cat", emoji: "🐱", referenceURL: cat, takeURL: owl, boothURL: booth,
            score: ImitationScore(rhythm: 90, pitch: 90, tone: 90, duration: 90),
            verdict: ImitationVerdict.forGrade(.perfect, seed: 0), seed: 1,
            artworkName: "imitate-cat"
        )
        let url = try await ImitationReelRenderer.render(reel) { _ in }
        defer { try? FileManager.default.removeItem(at: url) }

        let timeline = ImitationReelTimeline(referenceDuration: try seconds(of: cat), takeDuration: takeSeconds)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (frame, _) = try await generator.image(at: CMTime(seconds: timeline.takeStart + 0.5, preferredTimescale: 600))

        // Middle of the frame, above the darkened waveform band: the footage's green.
        let pixel = try #require(rgb(of: frame, at: CGPoint(x: frame.width / 2, y: frame.height / 3)))
        #expect(pixel.green > 150)
        #expect(pixel.red < 60 && pixel.blue < 60)
    }

    /// A portrait H.264 clip of one flat colour, standing in for the front camera.
    private func writeSolidClip(to url: URL, seconds: Double, green: UInt8) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 360, AVVideoHeightKey: 640
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: 360, kCVPixelBufferHeightKey as String: 640
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<Int(seconds * 30) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let base = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self)
            for row in 0..<640 {
                let line = base + row * CVPixelBufferGetBytesPerRow(pixels)
                for column in 0..<360 {
                    line[column * 4] = 0; line[column * 4 + 1] = green; line[column * 4 + 2] = 0; line[column * 4 + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
    }

    private func rgb(of image: CGImage, at point: CGPoint) -> (red: Int, green: Int, blue: Int)? {
        var bytes = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: -point.x, y: -(CGFloat(image.height) - point.y), width: CGFloat(image.width), height: CGFloat(image.height)))
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
    }

    private func seconds(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }
}
