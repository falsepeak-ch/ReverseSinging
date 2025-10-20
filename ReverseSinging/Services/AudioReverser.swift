//
//  AudioReverser.swift
//  ReverseSinging
//
//  Audio reversal service using AVAudioEngine
//

import AVFoundation

final class AudioReverser {
    static let shared = AudioReverser()

    private init() {}

    // MARK: - Reverse Audio

    func reverseAudio(inputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let audioFile = try AVAudioFile(forReading: inputURL)
                let format = audioFile.processingFormat
                let frameCount = UInt32(audioFile.length)

                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    throw AudioReverserError.bufferCreationFailed
                }

                try audioFile.read(into: buffer)

                // Reverse the audio buffer
                self.reverseBuffer(buffer)

                // Save to new file
                let outputURL = AudioFileManager.shared.createTemporaryAudioURL()
                let outputFile = try AVAudioFile(
                    forWriting: outputURL,
                    settings: format.settings,
                    commonFormat: format.commonFormat,
                    interleaved: format.isInterleaved
                )

                try outputFile.write(from: buffer)

                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Buffer Reversal

    private func reverseBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        for channel in 0..<channelCount {
            var data = Array(UnsafeBufferPointer(start: floatChannelData[channel], count: frameLength))
            data.reverse()

            for (index, value) in data.enumerated() {
                floatChannelData[channel][index] = value
            }
        }
    }
}

// MARK: - Errors

enum AudioReverserError: LocalizedError {
    case bufferCreationFailed
    case fileReadFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .fileReadFailed:
            return "Failed to read audio file"
        case .fileWriteFailed:
            return "Failed to write audio file"
        }
    }
}
