//
//  HostNode.swift
//  DubloonGame
//
//  The game-show host: breathes, blinks, talks and cheers.
//

import SpriteKit

/// The host sprite and her animation.
///
/// Idle is never still: a slow breath on the body and a blink every few seconds. Talking flips
/// between the talk and idle frames; cheering swaps to delight with a hop.
final class HostNode: SKNode {
    private let body: SKSpriteNode
    private let textures: [GameArt.Host: SKTexture]
    private let reduceMotion: Bool

    init(atlas: SKTextureAtlas, reduceMotion: Bool) {
        var textures: [GameArt.Host: SKTexture] = [:]
        for pose in GameArt.Host.allCases { textures[pose] = atlas.textureNamed(pose.rawValue) }
        self.textures = textures
        self.reduceMotion = reduceMotion
        body = SKSpriteNode(texture: textures[.idle])
        // Feet on the floor: everything below scales and hops from there.
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        super.init()
        addChild(body)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Scales the host to `height` points, feet at this node's origin.
    func layout(height: CGFloat) {
        let base = textures[.idle]?.size().height ?? 1
        setScale(height / base)
    }

    // MARK: - Animation

    func startIdle() {
        guard !reduceMotion else { return }
        body.removeAction(forKey: "breath")
        let inhale = SKAction.scaleY(to: 1.015, duration: 1.6)
        inhale.timingMode = .easeInEaseOut
        let exhale = SKAction.scaleY(to: 1.0, duration: 1.6)
        exhale.timingMode = .easeInEaseOut
        let sway = SKAction.sequence([.rotate(toAngle: 0.012, duration: 2.4), .rotate(toAngle: -0.012, duration: 2.4)])
        body.run(.group([.repeatForever(.sequence([inhale, exhale])), .repeatForever(sway)]), withKey: "breath")
        scheduleBlink()
    }

    private func scheduleBlink() {
        guard let idle = textures[.idle], let blink = textures[.blink] else { return }
        let once = SKAction.sequence([
            .wait(forDuration: 3.2, withRange: 2.8),
            .run { [weak self] in
                // Only from the idle face: never in the middle of a line or a cheer.
                guard let self, self.body.texture == idle else { return }
                self.body.run(.sequence([.setTexture(blink), .wait(forDuration: 0.12), .setTexture(idle)]))
            },
        ])
        run(.repeatForever(once), withKey: "blink")
    }

    /// Mouths along for about as long as the line takes to appear.
    func talk(for duration: TimeInterval) {
        guard !reduceMotion, let talk = textures[.talk], let idle = textures[.idle] else { return }
        body.removeAction(forKey: "pose")
        let flaps = max(Int(duration / 0.3), 1)
        let flap = SKAction.sequence([
            .setTexture(talk), .wait(forDuration: 0.15, withRange: 0.06),
            .setTexture(idle), .wait(forDuration: 0.15, withRange: 0.06),
        ])
        body.run(.repeat(flap, count: flaps), withKey: "pose")
    }

    /// How long `cheer()` takes to land, for whoever waits on it.
    static let cheerDuration: TimeInterval = 0.42

    /// A delighted hop.
    func cheer() {
        guard let delight = textures[.delight], let idle = textures[.idle] else { return }
        body.removeAction(forKey: "pose")
        let jumpHeight = 24 / max(yScale, 0.01)
        let up = SKAction.moveBy(x: 0, y: jumpHeight, duration: 0.14)
        up.timingMode = .easeOut
        let down = up.reversed()
        down.timingMode = .easeIn
        let squash = SKAction.sequence([.scaleX(to: 1.06, y: 0.94, duration: 0.06), .scaleX(to: 1, y: 1, duration: 0.08)])
        let hop: SKAction = reduceMotion ? .wait(forDuration: 0.25) : .sequence([up, down, squash])
        body.run(.sequence([.setTexture(delight), hop, .wait(forDuration: 0.4), .setTexture(idle)]), withKey: "pose")
    }
}
