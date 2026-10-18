//
//  HostClip.swift
//  DubloonGame
//
//  The host's four-frame clips from the voxhop animation kit, with the kit's own timing.
//

import SpriteKit

/// One of the kit's character clips.
///
/// Every frame sits on the same 576 × 864 registered canvas with her feet on one baseline, so
/// a clip can follow another on the same sprite without her jumping. The holds are the kit's
/// (`animations.json`): idle breathes and blinks inside its own frames, which is why it holds
/// its first frame for over two seconds.
enum HostClip: String, CaseIterable {
    case idle, talk, wave, cheer, surprise

    /// Milliseconds per frame, from the kit's manifest.
    var holds: [Int] {
        switch self {
        case .idle: [2200, 280, 100, 800]
        case .talk: [100, 140, 110, 160]
        case .wave: [180, 160, 160, 240]
        case .cheer: [160, 140, 220, 240]
        case .surprise: [180, 120, 350, 300]
        }
    }

    /// Played round and round rather than once and held.
    var loops: Bool { self == .idle || self == .talk || self == .wave }

    /// The kit's anchor: centred, a little above the bottom of the canvas, where her soles are.
    static let anchor = CGPoint(x: 0.5, y: 0.037)

    static let atlas = "HostClips"

    func textureName(_ frame: Int) -> String { "game-host-\(rawValue)-0\(frame)" }

    /// One pass through the clip in the kit's timing.
    var duration: TimeInterval { Double(holds.reduce(0, +)) / 1000 }
}

/// The clips' textures, loaded once and shared by every stage that shows the host.
@MainActor
enum HostClipLibrary {
    private static var cache: [HostClip: [SKTexture]] = [:]

    static func frames(_ clip: HostClip) -> [SKTexture] {
        if let frames = cache[clip] { return frames }
        let atlas = SKTextureAtlas(named: HostClip.atlas)
        let frames = (0..<clip.holds.count).map { atlas.textureNamed(clip.textureName($0)) }
        cache[clip] = frames
        return frames
    }

    /// One pass of `clip` on a sprite, each frame held as long as the kit says.
    static func pass(_ clip: HostClip, speed: Double = 1) -> SKAction {
        let frames = frames(clip)
        let steps = zip(frames, clip.holds).map { texture, hold in
            SKAction.sequence([.setTexture(texture), .wait(forDuration: Double(hold) / 1000 / speed)])
        }
        return .sequence(steps)
    }

    /// Warms the textures off the first frame of the stage.
    static func preload() async {
        await SKTextureAtlas(named: HostClip.atlas).preload()
    }
}

/// The host as a sprite that plays the kit's clips.
///
/// Idle loops on its own; every other clip is played over it and falls back to idle when it
/// ends (a looping clip after `repeats` passes). Transforms — hops, leans, glides — belong to
/// whoever owns this node; this only swaps frames.
final class HostSprite: SKSpriteNode {
    private(set) var clip: HostClip = .idle
    private let reduceMotion: Bool

    init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        let first = HostClipLibrary.frames(.idle)[0]
        super.init(texture: first, color: .clear, size: first.size())
        anchorPoint = HostClip.anchor
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    /// The canvas height in points at scale 1, for callers sizing her.
    var canvasHeight: CGFloat { HostClipLibrary.frames(.idle)[0].size().height }

    /// How much of the canvas her figure fills, soles to hair (748 of 864 pixels in the kit's
    /// registration report); the rest is padding above her head and under the anchor.
    static let figureFraction: CGFloat = 0.87

    /// Plays `clip`, `repeats` times if it loops, then returns to idle. Idle itself loops for
    /// ever. With Reduce Motion she holds the clip's most telling frame instead.
    func play(_ clip: HostClip, repeats: Int = 1, then: (() -> Void)? = nil) {
        self.clip = clip
        removeAction(forKey: "clip")
        let frames = HostClipLibrary.frames(clip)

        guard !reduceMotion else {
            texture = clip == .idle ? frames[0] : frames[frames.count - 1]
            if clip != .idle {
                run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in
                    self?.play(.idle)
                    then?()
                }]), withKey: "clip")
            }
            return
        }

        if clip == .idle {
            run(.repeatForever(HostClipLibrary.pass(.idle)), withKey: "clip")
            return
        }

        let body: SKAction = clip.loops
            ? .repeat(HostClipLibrary.pass(clip), count: max(repeats, 1))
            // A one-shot holds its last frame a beat, as the kit's guide suggests.
            : .sequence([HostClipLibrary.pass(clip), .wait(forDuration: 0.35)])
        run(.sequence([body, .run { [weak self] in
            self?.play(.idle)
            then?()
        }]), withKey: "clip")
    }

    /// Talks for about `duration` seconds: whole passes of the talk clip.
    func talk(for duration: TimeInterval) {
        guard duration > 0 else { return }
        play(.talk, repeats: max(Int((duration / HostClip.talk.duration).rounded()), 1))
    }
}
