//
//  HomeVideoMixerTests.swift
//  ReverseSingingTests
//
//  The Home Video Dub export: picture kept, voice laid on, in sync
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

@Suite("Home Video Mixer")
struct HomeVideoMixerTests {

    @Test func inspectMeasuresAClip() async throws {
        let clip = temporaryURL("mov")
        defer { try? FileManager.default.removeItem(at: clip) }
        try await writeClip(to: clip, seconds: 2)

        let source = try await HomeVideoMixer.inspect(clip)
        #expect(abs(source.duration - 2) < 0.1)
        #expect(!source.wasTrimmed)
        #expect(!source.hasSound)
    }

    @Test(.timeLimit(.minutes(2)))
    func aLongClipIsCutToTheFirstMinute() async throws {
        let clip = temporaryURL("mov")
        defer { try? FileManager.default.removeItem(at: clip) }
        try await writeClip(to: clip, seconds: 62, framesPerSecond: 2)

        let source = try await HomeVideoMixer.inspect(clip)
        #expect(source.duration == HomeVideoMixer.maximumDuration)
        #expect(source.wasTrimmed)
    }

    @Test func aFileWithoutPictureIsRefused() async throws {
        let sound = temporaryURL("caf")
        defer { try? FileManager.default.removeItem(at: sound) }
        try writeTone(to: sound, seconds: 1, onset: 0)

        await #expect(throws: HomeVideoMixer.MixError.self) {
            _ = try await HomeVideoMixer.inspect(sound)
        }
    }

    /// The voice's first sound lands where it was spoken: AAC priming lost on the way back
    /// into a composition once put the dub export 40 ms late, which a viewer sees on lips.
    @Test(.timeLimit(.minutes(2)))
    func theVoiceLandsInSyncWithThePicture() async throws {
        let clip = temporaryURL("mov")
        let voice = temporaryURL("caf")
        let output = temporaryURL("mp4")
        defer {
            for url in [clip, voice, output] { try? FileManager.default.removeItem(at: url) }
        }
        try await writeClip(to: clip, seconds: 2)
        try writeTone(to: voice, seconds: 2, onset: 0.5)

        let source = try await HomeVideoMixer.inspect(clip)
        let result = try await HomeVideoMixer.render(source: source, voice: voice, keepOriginal: true, to: output)
        defer { try? FileManager.default.removeItem(at: result) }

        let asset = AVURLAsset(url: result)
        #expect(try await !asset.loadTracks(withMediaType: .video).isEmpty)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 2) < 0.1)

        let onset = try #require(try await firstSound(in: asset))
        #expect(abs(onset - 0.5) < 0.015, "voice starts at \(onset) s")
    }

    // MARK: - Fixtures

    private func temporaryURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("home-video-\(UUID().uuidString).\(ext)")
    }

    /// A small silent H.264 clip.
    private func writeClip(to url: URL, seconds: Double, framesPerSecond: Int32 = 30) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let frames = Int(seconds * Double(framesPerSecond))
        for frame in 0...frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            let pixels = try #require(buffer)
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: framesPerSecond))
        }
        input.markAsFinished()
        await writer.finishWriting()
    }

    /// Silence, then a steady 440 Hz tone from `onset` to the end.
    private func writeTone(to url: URL, seconds: Double, onset: Double) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let frames = AVAudioFrameCount(seconds * 44_100)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let samples = try #require(buffer.floatChannelData?[0])
        let start = Int(onset * 44_100)
        for index in 0..<Int(frames) {
            samples[index] = index < start ? 0 : 0.3 * sin(2 * .pi * 440 * Float(index - start) / 44_100)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    /// Seconds to the first sample above a tenth of the track's peak.
    private func firstSound(in asset: AVURLAsset) async throws -> Double? {
        let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false
        ])
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []
        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var chunk = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
            _ = chunk.withUnsafeMutableBytes { raw in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
            }
            samples += chunk
        }
        let peak = samples.map(abs).max() ?? 0
        guard peak > 0, let index = samples.firstIndex(where: { abs($0) > peak * 0.1 }) else { return nil }
        return Double(index) / 44_100
    }
}
