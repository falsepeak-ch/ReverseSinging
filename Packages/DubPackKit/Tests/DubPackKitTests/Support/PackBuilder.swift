//
//  PackBuilder.swift
//  DubPackKitTests
//

import AVFoundation
import CoreVideo
import Foundation

/// Writes a pack onto disk one file at a time, so each test can leave out, rename or break
/// exactly the thing it is about.
struct PackBuilder {
    let directory: URL

    /// A pack folder called `name` inside `parent`.
    init(in parent: URL, named name: String = "Test Scene") throws {
        directory = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Text

    func write(_ text: String, to name: String, encoding: String.Encoding = .utf8) throws {
        try text.write(to: directory.appendingPathComponent(name), atomically: true, encoding: encoding)
    }

    func write(_ data: Data, to name: String) throws {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    /// `_pack_info.ini` with the given field lines under a `[data]` header.
    func packInfo(
        _ fields: [String] = ["title=\"Test Scene\"", "authors=[\"Tester\"]"],
        named name: String = "_pack_info.ini",
        lineEnding: String = "\n"
    ) throws {
        try write((["[data]", ""] + fields + [""]).joined(separator: lineEnding), to: name)
    }

    /// A line entry `slug.txt` with the given field lines under a `[data]` header.
    func entry(_ slug: String, _ fields: [String], lineEnding: String = "\n") throws {
        try write((["[data]", ""] + fields + [""]).joined(separator: lineEnding), to: "\(slug).txt")
    }

    /// A complete, conventional line: `slug.txt` + `slug.jpg` + a silent `slug.wav`.
    func line(
        _ slug: String,
        at timestamp: Double,
        character: String? = nil,
        caption: String = "A line",
        audioDuration: Double = 1
    ) throws {
        var fields = [
            "caption=\"\(caption)\"",
            "image=\"\(slug).jpg\"",
            "dub_timestamps=[\(String(format: "%.3f", timestamp))]",
        ]
        if let character { fields.append("dub_characters=[\"\(character)\"]") }
        try entry(slug, fields)
        try still("\(slug).jpg")
        try silentWav("\(slug).wav", duration: audioDuration)
    }

    // MARK: - Media

    /// The first bytes of a JPEG. Enough for anything that only checks a still exists.
    func still(_ name: String) throws {
        try write(Data([0xFF, 0xD8, 0xFF, 0xE0]), to: name)
    }

    /// A real, decodable 48 kHz mono PCM file.
    func silentWav(_ name: String, duration: Double = 1) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
        try writeSilence(to: name, settings: format.settings, format: format, duration: duration)
    }

    /// A real, decodable AAC file, the way the in-house pack builder writes a backing track.
    func silentAAC(_ name: String, duration: Double = 1) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
        ]
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        try writeSilence(to: name, settings: settings, format: format, duration: duration)
    }

    private func writeSilence(to name: String, settings: [String: Any], format: AVAudioFormat, duration: Double) throws {
        let url = directory.appendingPathComponent(name)
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames)!
        buffer.frameLength = frames
        try file.write(from: buffer)
    }

    /// A real, decodable H.264 video of black frames at 10 fps.
    func h264Video(_ name: String, duration: Double = 1) throws {
        let url = directory.appendingPathComponent(name)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 48,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: 64,
                kCVPixelBufferHeightKey as String: 48,
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 10
        let frameCount = Int(duration * Double(fps))
        for frame in 0..<frameCount {
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool!, &pixelBuffer)
            guard let pixelBuffer else { continue }
            while !input.isReadyForMoreMediaData { usleep(1000) }
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }

        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: fps))
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
    }

    func copyFixture(_ fixture: String, as name: String) throws {
        try FileManager.default.copyItem(at: Fixtures.url(fixture), to: directory.appendingPathComponent(name))
    }

    func remove(_ name: String) throws {
        try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}
