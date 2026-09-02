//
//  SoundManager.swift
//  ReverseSinging
//
//  Interface sound effects: the clapper, the transport, the render.
//

import AVFoundation
import Foundation

/// The app's interface sounds. Short, dry and used sparingly. They mark the moments
/// that matter (slate, take saved, render done) rather than every tap.
enum UISound: String, CaseIterable {
    case clapperSnap = "clapper-snap"
    case tapeStop = "tape-stop"
    case mechanicalClick = "mechanical-click"
    case reelSpinUp = "reel-spin-up"
    case projectorChime = "projector-chime"
    case errorThunk = "error-thunk"
    case countBeep = "count-beep"
    case countBeepGo = "count-beep-go"

    /// Level relative to the interface, so the clapper lands and the click stays polite.
    var volume: Float {
        switch self {
        case .clapperSnap: return 0.9
        case .tapeStop: return 0.6
        case .mechanicalClick: return 0.35
        case .reelSpinUp: return 0.5
        case .projectorChime: return 0.7
        case .errorThunk: return 0.6
        case .countBeep: return 0.75
        case .countBeepGo: return 0.9
        }
    }

    /// How long the sound runs, for callers that need to wait it out.
    var duration: TimeInterval {
        switch self {
        case .clapperSnap: return 0.22
        case .tapeStop: return 0.38
        case .mechanicalClick: return 0.10
        case .reelSpinUp, .projectorChime: return 1.5
        case .errorThunk: return 0.28
        case .countBeep: return 0.12
        case .countBeepGo: return 0.16
        }
    }
}

final class SoundManager: @unchecked Sendable {

    static let shared = SoundManager()

    private static let enabledKey = "soundsEnabled"

    /// Players are kept alive per sound so repeated triggers don't re-decode the file.
    ///
    /// Guarded by a lock rather than a serial queue: `play` used to hop onto a background
    /// queue, which under load (waveform sampling, video decode) got scheduled late enough
    /// to hear. Taking a lock and calling `play()` on the caller's thread is immediate,
    /// `AVAudioPlayer.play()` returns straight away and does its work on the audio thread.
    private var players: [UISound: AVAudioPlayer] = [:]
    private let lock = NSLock()
    private let loadQueue = DispatchQueue(label: "com.falsepeak.dubloon.sound", qos: .userInitiated)

    /// Set while the mic is open. Interface sounds would bleed straight into the take,
    /// so everything is suppressed until recording stops.
    private var isMicrophoneOpen = false

    var isEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: Self.enabledKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: Self.enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private init() {}

    // MARK: - Loading

    /// Decodes every sound up front. Called once at launch so the first clapper is
    /// as immediate as the rest.
    func preload() {
        loadQueue.async { [self] in
            for sound in UISound.allCases {
                guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
                      let player = try? AVAudioPlayer(contentsOf: url) else {
                    continue
                }

                player.volume = sound.volume
                player.prepareToPlay()

                lock.lock()
                if players[sound] == nil { players[sound] = player }
                lock.unlock()
            }
        }
    }

    // MARK: - Playback

    func play(_ sound: UISound) {
        guard isEnabled else { return }

        lock.lock()
        let player = isMicrophoneOpen ? nil : players[sound]
        lock.unlock()

        guard let player else { return }
        player.currentTime = 0
        player.play()
    }

    /// Tells the manager the mic is live, so nothing is played into the take.
    func setMicrophoneOpen(_ isOpen: Bool) {
        lock.lock()
        defer { lock.unlock() }

        isMicrophoneOpen = isOpen
        guard isOpen else { return }

        for player in players.values where player.isPlaying {
            player.stop()
            // `stop()` throws away the prepared state; without this the next trigger has to
            // prepare first, which is exactly the lag this class exists to avoid.
            player.prepareToPlay()
        }
    }

    // MARK: - Settings

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled { play(.mechanicalClick) }
    }
}
