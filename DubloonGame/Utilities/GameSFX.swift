//
//  GameSFX.swift
//  DubloonGame
//
//  The game show's sound effects: taps, stings, the count, stars and the crowd.
//

import AVFoundation

/// A game-show sound. The files live in `Resources/GameSFX` as `<rawValue>.caf`, cut and
/// levelled from CC0 sources listed in `DesignAssets/game-sfx/SELECTION.md` (Kenney,
/// OpenGameArt, Freesound). The count-in keeps the shared `UISound` beeps, whose lengths
/// time the mic opening.
nonisolated enum GameSFX: String, CaseIterable {
    case tap
    case select
    case back
    case whoosh
    case pop
    case coin
    case tick
    case star
    case fanfare
    case fail
    case cheer

    /// Level against the rest, so a tap stays polite and the fanfare lands.
    var volume: Float {
        switch self {
        case .tap, .tick: 0.4
        case .back, .whoosh, .pop: 0.55
        case .select, .coin: 0.7
        case .star: 0.75
        case .fanfare, .cheer: 0.8
        case .fail: 0.65
        }
    }

    /// How many can sound at once: ticks and stars overlap in a reveal.
    var voices: Int {
        switch self {
        case .tick, .star, .pop, .tap: 3
        default: 1
        }
    }

    /// Plays the sound, unless sounds are off or the mic is open.
    static func play(_ sound: GameSFX, pitch: Float = 1) {
        GameSFXPlayer.shared.play(sound, pitch: pitch)
    }

    /// The nth star of a reveal: each one a step higher than the last.
    static func star(_ index: Int) {
        play(.star, pitch: [1, 1.122, 1.26][min(max(index, 0), 2)])
    }
}

/// Keeps a few prepared players per sound. Shares Dubloon's sound switch and steps aside
/// while the mic is open, like `SoundManager`.
nonisolated final class GameSFXPlayer: @unchecked Sendable {
    static let shared = GameSFXPlayer()

    private var players: [GameSFX: [AVAudioPlayer]] = [:]
    private var next: [GameSFX: Int] = [:]
    private let lock = NSLock()
    private let loadQueue = DispatchQueue(label: "com.falsepeak.dubloon-game.sfx", qos: .userInitiated)

    private init() {}

    func preload() {
        loadQueue.async { [self] in
            for sound in GameSFX.allCases {
                guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") else { continue }
                let voices: [AVAudioPlayer] = (0..<sound.voices).compactMap { _ in
                    guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                    player.volume = sound.volume
                    player.enableRate = true
                    player.prepareToPlay()
                    return player
                }
                lock.lock()
                players[sound] = voices
                lock.unlock()
            }
        }
    }

    func play(_ sound: GameSFX, pitch: Float) {
        let manager = SoundManager.shared
        guard manager.isEnabled, !manager.microphoneIsOpen else { return }

        lock.lock()
        let voices = players[sound] ?? []
        let index = next[sound, default: 0]
        next[sound] = (index + 1) % max(voices.count, 1)
        lock.unlock()

        guard !voices.isEmpty else { return }
        let player = voices[index % voices.count]
        // `rate` shifts pitch and speed together, which is what a rising star should do.
        player.rate = pitch
        player.currentTime = 0
        player.play()
    }
}
