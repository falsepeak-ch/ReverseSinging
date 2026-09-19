//
//  MediaProbe.swift
//  DubPackKit
//

import AVFoundation
import Foundation

/// Asks the media frameworks what a file holds.
///
/// A protocol so tests can declare "this file does not decode" without depending on which
/// formats a given OS version happens to decode.
protocol MediaProbe: Sendable {
    /// Seconds of audio, or nil when the file is not audio this platform can decode.
    func audioDuration(of url: URL) -> TimeInterval?

    /// Seconds of video, or nil when the file has no video track this platform can decode.
    func videoDuration(of url: URL) async -> TimeInterval?
}

struct AVFoundationMediaProbe: MediaProbe {

    func audioDuration(of url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0, file.length > 0 else { return nil }
        return Double(file.length) / sampleRate
    }

    func videoDuration(of url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .video), !tracks.isEmpty,
              let duration = try? await asset.load(.duration) else {
            return nil
        }
        let seconds = duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}
