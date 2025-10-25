//
//  AudioSessionManager.swift
//  ReverseSinging
//
//  Centralized audio session management to prevent conflicts
//

import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private let audioSession = AVAudioSession.sharedInstance()
    private var isConfigured = false

    private init() {}

    // MARK: - Configuration

    /// Configure the audio session once for the entire app
    /// Uses .playAndRecord to support both recording and playback
    func configure() {
        guard !isConfigured else { return }

        do {
            // Use .playAndRecord category to support both recording and playback
            // .defaultToSpeaker: Play audio through speaker (not earpiece)
            // .allowBluetooth: Support Bluetooth devices
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )

            print("✅ Audio session configured (.playAndRecord)")
            isConfigured = true
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Activation

    /// Activate the audio session (call before recording/playback)
    func activate() {
        configure() // Ensure configured before activating

        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session activated")
        } catch {
            print("❌ Failed to activate audio session: \(error)")
        }
    }

    /// Deactivate the audio session (call when done with audio)
    func deactivate() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }

    // MARK: - Permission

    func requestRecordPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                print(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
                completion(granted)
            }
        }
    }
}
