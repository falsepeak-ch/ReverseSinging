//
//  HostNode.swift
//  DubloonGame
//
//  The game-show host on the home stage: waves you in, talks, cheers you off to a game.
//

import SpriteKit

/// The host on the home stage, played from the animation kit's clips (`HostSprite`).
///
/// The clips carry the face and arms; this node adds what they cannot: a slow sway, a hop
/// with squash on a cheer, a jolt on a surprise.
final class HostNode: SKNode {
    private let body: HostSprite
    private let reduceMotion: Bool

    init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        body = HostSprite(reduceMotion: reduceMotion)
        super.init()
        addChild(body)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Scales the host so she stands `height` points from soles to hair, soles at this node's
    /// origin.
    func layout(height: CGFloat) {
        setScale(height / (body.canvasHeight * HostSprite.figureFraction))
    }

    // MARK: - Animation

    /// Idle, with a wave hello first.
    func startIdle(greeting: Bool) {
        if greeting {
            body.play(.wave, repeats: 3)
        } else {
            body.play(.idle)
        }
        guard !reduceMotion, body.action(forKey: "sway") == nil else { return }
        let sway = SKAction.sequence([
            .rotate(toAngle: 0.012, duration: 2.4),
            .rotate(toAngle: -0.012, duration: 2.4),
        ])
        sway.timingMode = .easeInEaseOut
        body.run(.repeatForever(sway), withKey: "sway")
    }

    /// Mouths along for about as long as the line takes to appear.
    func talk(for duration: TimeInterval) {
        body.talk(for: duration)
    }

    /// How long `cheer()` takes to land, for whoever waits on it.
    static let cheerDuration: TimeInterval = 0.5

    /// A fist pump and a hop.
    func cheer() {
        body.play(.cheer)
        guard !reduceMotion else { return }
        let jumpHeight = 26 / max(yScale, 0.01)
        let up = SKAction.moveBy(x: 0, y: jumpHeight, duration: 0.16)
        up.timingMode = .easeOut
        let down = up.reversed()
        down.timingMode = .easeIn
        let squash = SKAction.sequence([
            .scaleX(to: 1.07, y: 0.93, duration: 0.06),
            .scaleX(to: 1, y: 1, duration: 0.1),
        ])
        body.run(.sequence([up, down, squash]), withKey: "hop")
    }

    /// A start: someone is out of free takes.
    func surprise() {
        body.play(.surprise)
        guard !reduceMotion else { return }
        let jolt = SKAction.sequence([
            .scaleX(to: 0.96, y: 1.05, duration: 0.08),
            .scaleX(to: 1, y: 1, duration: 0.18),
        ])
        body.run(jolt, withKey: "hop")
    }
}
