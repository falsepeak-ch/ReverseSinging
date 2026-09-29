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
        #if os(macOS)
        return .activationFailed(error)
        #else
        let code = AVAudioSession.ErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .insufficientPriority, .cannotInterruptOthers, .isBusy, .siriIsRecording,
             .cannotStartPlaying, .cannotStartRecording, .sessionNotActive:
            return .inUseElsewhere(error)
        default:
            return .activationFailed(error)
        }
        #endif
    }
}

/// On the Mac there is no audio session to configure or activate: the engine talks to the
/// default input and output devices directly. The same calls exist there and succeed, so the
/// recorder and the player need no platform checks of their own; only the microphone
/// permission is real on both.
final class AudioSessionManager {
    static let shared = AudioSessionManager()

    #if os(iOS)
    private let audioSession = AVAudioSession.sharedInstance()
    #endif
    private var isConfigured = false

    private init() {}

    // MARK: - Configuration

    /// Configure the audio session for the entire app
    /// Uses .playAndRecord to support both recording and playback
    ///
    /// Checked against the live session rather than only a flag. A media services reset puts
    /// the session back on its default `.soloAmbient` behind the app's back, and from then on
    /// every recorder was refused — "Failed to start recording", with the diagnostics showing
    /// that category and no input — until the app was killed.
    func configure() {
        #if os(macOS)
        isConfigured = true
        #else
        guard !isConfigured || !isPlayAndRecord else { return }
        if isConfigured {
            CrashReporter.shared.log("audio_session.category_lost: \(audioSession.category.rawValue), reconfiguring")
        }

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
        #endif
    }

    #if os(iOS)
    /// The category, and the speaker option: `.playAndRecord` without `.defaultToSpeaker` is what
    /// something else leaves behind, and it routes a take's playback to the earpiece.
    private var isPlayAndRecord: Bool {
        audioSession.category == .playAndRecord && audioSession.categoryOptions.contains(.defaultToSpeaker)
    }
    #endif

    // MARK: - Activation

    /// Activates the audio session. Call before recording or playback, and stop there when it
    /// throws: an engine built over an inactive session has no output format to build against,
    /// and `AVAudioEngine` answers that by raising, not by returning an error.
    ///
    /// Another app holding the hardware is reported to the user, not to Crashlytics; it was
    /// the single most common event in the crash reporter and said nothing about this app.
    func activate() throws(AudioSessionError) {
        configure() // Ensure configured before activating

        #if os(iOS)
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
        #endif
    }

    /// `activate()`, for callers with nowhere to put an error. False means do not touch the engine.
    @discardableResult
    func tryActivate() -> Bool {
        (try? activate()) != nil
    }

    /// Deactivate the audio session (call when done with audio)
    func deactivate() {
        #if os(iOS)
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            // Not reported: another app holding the session is normal and self-corrects.
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
        #endif
    }

    /// True when the output has somewhere to go, which is what an `AVAudioEngine` graph needs
    /// before a single node can be connected to its mixer.
    var hasOutputRoute: Bool {
        #if os(iOS)
        !audioSession.currentRoute.outputs.isEmpty && audioSession.sampleRate > 0
        #else
        true
        #endif
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

    /// True only when the user said no. Never asked is not denied: the first recording asks.
    var isRecordPermissionDenied: Bool {
        return AVAudioApplication.shared.recordPermission == .denied
    }
}
