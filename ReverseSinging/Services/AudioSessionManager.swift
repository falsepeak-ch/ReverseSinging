//
//  AudioSessionManager.swift
//  ReverseSinging
//
//  Centralized audio session management to prevent conflicts
//

import AVFoundation

/// Why the audio session could not be made active.
enum AudioSessionError: LocalizedError {
    /// Another app holds the audio hardware: a call, Siri, a recorder. Nothing here can play
    /// or record until it lets go, and nothing here did anything wrong.
    case inUseElsewhere(Error)
    /// The system refused for a reason of its own.
    case activationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .inUseElsewhere: Strings.Error.audioInUse
        case .activationFailed(let error): error.localizedDescription
        }
    }

    /// True when the failure is the device's situation rather than the app's: not worth a
    /// crash report, worth a sentence to the user.
    var isEnvironmental: Bool {
        if case .inUseElsewhere = self { return true }
        return false
    }

    /// The `AVAudioSession.ErrorCode`s that mean "not now" rather than "never".
    static func classify(_ error: Error) -> AudioSessionError {
        let code = AVAudioSession.ErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .insufficientPriority, .cannotInterruptOthers, .isBusy, .siriIsRecording,
             .cannotStartPlaying, .cannotStartRecording, .sessionNotActive:
            return .inUseElsewhere(error)
        default:
            return .activationFailed(error)
        }
    }
}

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
                options: [.defaultToSpeaker, AVAudioSession.CategoryOptions.allowBluetoothHFP]
            )

            print("✅ Audio session configured (.playAndRecord)")
            isConfigured = true
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            // Nothing downstream can record or play if this failed, so it is the first
            // thing worth knowing about when a user reports silence.
            CrashReporter.shared.record(error, context: "audio_session.configure")
        }
    }

    // MARK: - Activation

    /// Activates the audio session. Call before recording or playback, and stop there when it
    /// throws: an engine built over an inactive session has no output format to build against,
    /// and `AVAudioEngine` answers that by raising, not by returning an error.
    ///
    /// Another app holding the hardware is reported to the user, not to Crashlytics; it was
    /// the single most common event in the crash reporter and said nothing about this app.
    func activate() throws(AudioSessionError) {
        configure() // Ensure configured before activating

        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session activated")
        } catch {
            let classified = AudioSessionError.classify(error)
            print("❌ Failed to activate audio session: \(error)")
            if classified.isEnvironmental {
                CrashReporter.shared.log("audio_session.activate refused: \((error as NSError).code)")
            } else {
                CrashReporter.shared.record(error, context: "audio_session.activate")
            }
            throw classified
        }
    }

    /// `activate()`, for callers with nowhere to put an error. False means do not touch the engine.
    @discardableResult
    func tryActivate() -> Bool {
        (try? activate()) != nil
    }

    /// Deactivate the audio session (call when done with audio)
    func deactivate() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            // Not reported: another app holding the session is normal and self-corrects.
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }

    /// True when the output has somewhere to go, which is what an `AVAudioEngine` graph needs
    /// before a single node can be connected to its mixer.
    var hasOutputRoute: Bool {
        !audioSession.currentRoute.outputs.isEmpty && audioSession.sampleRate > 0
    }

    // MARK: - Permission

    func requestRecordPermission(completion: @escaping (Bool) -> Void) {
        // The async form rather than the handler one: that handler is called on an arbitrary
        // thread and is not marked Sendable, so entering this main-actor code from it traps.
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            print(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
            completion(granted)
        }
    }

    /// Helper to check if permission is granted
    var hasRecordPermission: Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }
}
