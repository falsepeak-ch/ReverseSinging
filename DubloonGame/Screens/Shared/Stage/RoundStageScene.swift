//
//  RoundStageScene.swift
//  DubloonGame
//
//  The set behind a round: lights sweeping the stage, and the host presenting from its side.
//

import SpriteKit
import SwiftUI
import DubScoring

/// How the host is taking the round.
enum HostMood: Equatable {
    /// Waiting for the player.
    case idle
    /// Giving the prompt.
    case talking
    /// The mic is open: she leans in and keeps still.
    case listening
    /// A good score.
    case cheering
    /// A poor one.
    case wincing
}

/// Where the host stands, in the screen's top-left points.
struct HostPlacement: Equatable {
    /// Her horizontal centre.
    var centerX: CGFloat
    /// The top of her hair.
    var headTop: CGFloat
    /// Her waist. Whatever covers her below it (the deck, a desk) is SwiftUI on top.
    var waist: CGFloat
}

/// The stage behind a round. Everything the player touches is SwiftUI on top of it; this
/// draws the set, its lights, and the host, who stands wherever the round's layout places
/// her and glides there when the layout changes.
final class RoundStageScene: SKScene {

    var placement: HostPlacement? { didSet { if oldValue != placement { layoutHost(animated: oldValue != nil) } } }

    private let reduceMotion: Bool
    private let backdrop = SKSpriteNode(imageNamed: GameArt.stage)
    private var beams: [SKSpriteNode] = []
    /// The light on the host: off until she has something to celebrate.
    private let spot = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
    /// A coloured wash over the whole set: the red of "on air" while the mic is open.
    private let wash = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 10))
    private var lighting: Lighting?

    /// How the set is lit, from the host's mood.
    private enum Lighting: Equatable {
        case show, onAir, gold, dim

        /// Left lamp, right lamp: colour and strength.
        var lamps: [(SKColor, Float)] {
            switch self {
            case .show: [(SKColor(Color.gameCyan), 0.45), (SKColor(red: 1, green: 0.86, blue: 0.62, alpha: 1), 0.45)]
            case .onAir: [(SKColor(red: 1, green: 0.25, blue: 0.22, alpha: 1), 0.6), (SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1), 0.6)]
            case .gold: [(SKColor(red: 1, green: 0.8, blue: 0.25, alpha: 1), 0.7), (SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 1), 0.7)]
            case .dim: [(SKColor(red: 0.35, green: 0.5, blue: 0.8, alpha: 1), 0.18), (SKColor(red: 0.35, green: 0.5, blue: 0.8, alpha: 1), 0.18)]
            }
        }

        /// How fast the lamps sweep: a celebration swings them hard.
        var sweepSpeed: CGFloat {
            switch self {
            case .gold: 2.6
            case .onAir: 1.4
            default: 1
            }
        }
    }
    /// Moves and scales with the host's reactions; the sprite inside it swaps expressions.
    private let host = SKNode()
    private let hostSprite: SKSpriteNode
    private let poses: [GameArt.Host: SKTexture]
    private var mood: HostMood = .idle

    init(size: CGSize, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        let atlas = SKTextureAtlas(named: GameArt.hostAtlas)
        var poses: [GameArt.Host: SKTexture] = [:]
        for pose in GameArt.Host.allCases { poses[pose] = atlas.textureNamed(pose.rawValue) }
        self.poses = poses
        hostSprite = SKSpriteNode(texture: poses[.idle])
        // Feet at the origin, as the kit's guide recommends, so every expression lines up.
        hostSprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SKColor(Color.gameNavy)
        build()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    private func build() {
        backdrop.zPosition = -10
        addChild(backdrop)

        for (index, color) in [SKColor(Color.gameCyan), SKColor(red: 1, green: 0.86, blue: 0.62, alpha: 1)].enumerated() {
            let beam = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
            beam.anchorPoint = CGPoint(x: 0.5, y: 1)
            beam.shader = StageShaders.beam(color: color, strength: 0.45, seed: Float(index) * 0.41)
            beam.blendMode = .add
            beam.zPosition = -5
            beams.append(beam)
            addChild(beam)
        }

        // The host's own spotlight, from straight above, warm.
        spot.anchorPoint = CGPoint(x: 0.5, y: 1)
        spot.shader = StageShaders.beam(color: SKColor(red: 1, green: 0.9, blue: 0.55, alpha: 1), strength: 0.75, seed: 0.9)
        spot.blendMode = .add
        spot.zPosition = 4
        spot.alpha = 0
        addChild(spot)

        host.addChild(hostSprite)
        host.zPosition = 5
        addChild(host)

        wash.blendMode = .add
        wash.zPosition = 6
        wash.alpha = 0
        addChild(wash)
    }

    // MARK: - Layout

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutStage()
        layoutHost(animated: false)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        layoutStage()
        layoutHost(animated: false)
        startMotion()
        set(mood, force: true)
    }

    /// The set and its lights, fixed to the screen: the deck growing and shrinking over it
    /// must not make the room move.
    private func layoutStage() {
        guard size.width > 0 else { return }
        let w = size.width, h = size.height
        let art = backdrop.texture?.size() ?? size
        let fill = max(w / art.width, h * 0.72 / art.height) * 1.06
        backdrop.size = CGSize(width: art.width * fill, height: art.height * fill)
        backdrop.position = CGPoint(x: w / 2, y: h - backdrop.size.height / 2 + 30)

        for (index, beam) in beams.enumerated() {
            beam.size = CGSize(width: w * 0.8, height: h * 0.75)
            beam.position = CGPoint(x: index == 0 ? w * 0.22 : w * 0.78, y: h)
        }
        wash.size = CGSize(width: w, height: h)
        wash.position = CGPoint(x: w / 2, y: h / 2)
        layoutSpot()
    }

    private func layoutSpot() {
        guard let placement else { return }
        let h = size.height
        spot.size = CGSize(width: size.width * 0.9, height: max(placement.waist + 60, 100))
        spot.position = CGPoint(x: placement.centerX, y: h + 10)
    }

    // MARK: - Lighting

    private func light(_ new: Lighting) {
        guard new != lighting else { return }
        lighting = new
        for (beam, lamp) in zip(beams, new.lamps) {
            fade(beam.shader, to: lamp.0, strength: lamp.1)
            beam.speed = new.sweepSpeed
        }
        spot.removeAction(forKey: "light")
        spot.run(.fadeAlpha(to: new == .gold ? 1 : 0, duration: 0.35), withKey: "light")

        wash.removeAction(forKey: "light")
        if new == .onAir, !reduceMotion {
            wash.color = SKColor(red: 1, green: 0.15, blue: 0.1, alpha: 1)
            let pulse = SKAction.sequence([.fadeAlpha(to: 0.16, duration: 0.5), .fadeAlpha(to: 0.05, duration: 0.5)])
            wash.run(.repeatForever(pulse), withKey: "light")
        } else {
            wash.run(.fadeAlpha(to: 0, duration: 0.3), withKey: "light")
        }
    }

    /// Cross-fades a lamp's colour and strength over a third of a second.
    private func fade(_ shader: SKShader?, to color: SKColor, strength: Float) {
        guard let shader,
              let colorUniform = shader.uniformNamed("u_color"),
              let strengthUniform = shader.uniformNamed("u_strength") else { return }
        let fromColor = colorUniform.vectorFloat4Value
        let fromStrength = strengthUniform.floatValue
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let toColor = vector_float4(Float(r), Float(g), Float(b), 1)
        guard !reduceMotion else {
            colorUniform.vectorFloat4Value = toColor
            strengthUniform.floatValue = strength
            return
        }
        let duration: CGFloat = 0.35
        run(.customAction(withDuration: duration) { _, elapsed in
            let t = Float(min(1, elapsed / duration))
            colorUniform.vectorFloat4Value = fromColor + (toColor - fromColor) * t
            strengthUniform.floatValue = fromStrength + (strength - fromStrength) * t
        })
    }

    /// Puts the host where `placement` says, sized so head-to-waist fills the space between.
    private func layoutHost(animated: Bool) {
        guard size.height > 0, let placement else { return }
        layoutSpot()
        let h = size.height
        let texture = poses[.idle]?.size() ?? CGSize(width: 1, height: 1)
        // Her waist is a little under half way up the drawing from the top of her hair.
        let height = max(placement.waist - placement.headTop, 40) / 0.46
        let scale = height / texture.height
        let target = CGPoint(x: placement.centerX, y: h - placement.headTop - height)

        hostSprite.removeAction(forKey: "place")
        host.removeAction(forKey: "place")
        guard animated, !reduceMotion else {
            hostSprite.setScale(scale)
            host.position = target
            return
        }
        let move = SKAction.move(to: target, duration: 0.4)
        move.timingMode = .easeInEaseOut
        let grow = SKAction.scale(to: scale, duration: 0.4)
        grow.timingMode = .easeInEaseOut
        host.run(move, withKey: "place")
        hostSprite.run(grow, withKey: "place")
    }

    private func startMotion() {
        guard !reduceMotion else { return }
        for (index, beam) in beams.enumerated() where beam.action(forKey: "sweep") == nil {
            let direction: CGFloat = index == 0 ? 1 : -1
            beam.zRotation = direction * 0.08
            let out = SKAction.rotate(toAngle: direction * 0.3, duration: 3.2 + Double(index) * 0.8)
            out.timingMode = .easeInEaseOut
            let back = SKAction.rotate(toAngle: direction * 0.02, duration: 3.2 + Double(index) * 0.8)
            back.timingMode = .easeInEaseOut
            beam.run(.repeatForever(.sequence([out, back])), withKey: "sweep")
        }
        // The kit's idle: a gentle 3.4-second bob.
        let bob = SKAction.sequence([.moveBy(x: 0, y: 4, duration: 1.7), .moveBy(x: 0, y: -4, duration: 1.7)])
        bob.timingMode = .easeInEaseOut
        hostSprite.run(.repeatForever(bob), withKey: "bob")
    }

    // MARK: - Mood

    func set(_ newMood: HostMood, force: Bool = false) {
        guard force || newMood != mood else { return }
        mood = newMood
        switch newMood {
        case .listening: light(.onAir)
        case .cheering: light(.gold)
        case .wincing: light(.dim)
        case .idle, .talking: light(.show)
        }
        hostSprite.removeAction(forKey: "pose")
        host.removeAction(forKey: "react")
        guard let idle = poses[.idle] else { return }

        switch newMood {
        case .idle:
            hostSprite.texture = idle
            host.run(.group([.rotate(toAngle: 0, duration: 0.25), .scale(to: 1, duration: 0.25)]), withKey: "react")
            guard !reduceMotion, let blink = poses[.blink] else { return }
            let once = SKAction.sequence([
                .wait(forDuration: 3, withRange: 2.5),
                .setTexture(blink), .wait(forDuration: 0.12), .setTexture(idle),
            ])
            hostSprite.run(.repeatForever(once), withKey: "pose")
        case .talking:
            guard let talk = poses[.talk] else { return }
            let flap = SKAction.sequence([
                .setTexture(talk), .wait(forDuration: 0.15, withRange: 0.06),
                .setTexture(idle), .wait(forDuration: 0.13, withRange: 0.06),
            ])
            hostSprite.run(.sequence([.repeat(flap, count: 7), .run { [weak self] in self?.set(.idle) }]), withKey: "pose")
        case .listening:
            hostSprite.texture = idle
            if !reduceMotion {
                // Leans in to listen.
                host.run(.group([.rotate(toAngle: 0.05, duration: 0.2), .scale(to: 1.03, duration: 0.2)]), withKey: "react")
            }
        case .cheering:
            hostSprite.texture = poses[.delight] ?? idle
            guard !reduceMotion else { return }
            let hop = SKAction.sequence([
                .moveBy(x: 0, y: 14, duration: 0.12), .moveBy(x: 0, y: -14, duration: 0.14),
            ])
            host.run(.group([.rotate(toAngle: 0, duration: 0.12), .scale(to: 1, duration: 0.12)]), withKey: "react")
            // Delight for about a second, as the kit's guide times it, then back to idle.
            // Back to her resting face, with the gold lights still up for the result.
            hostSprite.run(.sequence([.repeat(hop, count: 3), .wait(forDuration: 0.5), .setTexture(idle)]), withKey: "pose")
        case .wincing:
            hostSprite.texture = poses[.blink] ?? idle
            guard !reduceMotion else { return }
            let shake = SKAction.sequence([
                .moveBy(x: -6, y: 0, duration: 0.05), .moveBy(x: 12, y: 0, duration: 0.08),
                .moveBy(x: -10, y: 0, duration: 0.07), .moveBy(x: 4, y: 0, duration: 0.05),
            ])
            host.run(.sequence([.group([.rotate(toAngle: 0, duration: 0.1), .scale(to: 1, duration: 0.1)]), shake]), withKey: "react")
            hostSprite.run(.sequence([.wait(forDuration: 0.9), .setTexture(idle)]), withKey: "pose")
        }
    }
}

/// A clear layer over the whole round for stars and confetti, so they fly over the cards and
/// the picture rather than behind them.
final class RoundFXScene: SKScene {
    private let reduceMotion: Bool
    private lazy var star = SKTextureAtlas(named: GameArt.UI.atlas).textureNamed(GameArt.UI.star)
    private lazy var props = SKTextureAtlas(named: GameArt.Props.atlas)

    init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Stars popping out of a point given in SwiftUI's top-left coordinates.
    func burst(at point: CGPoint, count: Int = 30) {
        guard !reduceMotion else { return }
        let e = SKEmitterNode()
        e.particleTexture = star
        e.numParticlesToEmit = count
        e.particleBirthRate = 800
        e.particleLifetime = 1.1
        e.particleLifetimeRange = 0.4
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 300
        e.particleSpeedRange = 140
        e.yAcceleration = -500
        e.particleScale = 0.6
        e.particleScaleRange = 0.3
        e.particleScaleSpeed = -0.4
        e.particleRotationSpeed = 4
        e.particleAlphaSpeed = -0.8
        e.particleColorBlendFactor = 0.6
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [SKColor(Color.gameGold), SKColor.white, SKColor(Color.gameCyan)],
            times: [0, 0.4, 1]
        )
        e.position = CGPoint(x: point.x, y: size.height - point.y)
        e.targetNode = self
        addChild(e)
        e.run(.sequence([.wait(forDuration: 2), .removeFromParent()]))
    }

    /// The end of a reveal: for a good take a fanfare, the crowd, confetti and ribbons; for a
    /// great one music notes too; for a poor one the sad trombone. Timed to land once the
    /// score has rolled up and the stars are in.
    func finale(for grade: DubGrade) {
        let stars = ScorePart.stars(for: grade)
        run(.sequence([
            .wait(forDuration: 0.9 + Double(stars) * 0.25),
            .run { [weak self] in
                guard let self else { return }
                guard grade.celebrates else {
                    GameSFX.play(.fail)
                    return
                }
                GameSFX.play(.fanfare)
                GameSFX.play(.pop)
                self.confetti()
                if stars == 3 {
                    GameSFX.play(.cheer)
                    self.notesShower()
                }
            },
        ]), withKey: "finale")
    }

    /// Music notes floating up the screen, for three stars.
    private func notesShower() {
        guard !reduceMotion else { return }
        let e = SKEmitterNode()
        e.particleTexture = props.textureNamed(GameArt.Props.note)
        e.numParticlesToEmit = 24
        e.particleBirthRate = 14
        e.particleLifetime = 3
        e.particleLifetimeRange = 0.8
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.5
        e.particleSpeed = 170
        e.particleSpeedRange = 60
        e.particleScale = 0.45
        e.particleScaleRange = 0.15
        e.particleRotationRange = 0.8
        e.particleRotationSpeed = 0.6
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 1, 0], times: [0, 0.1, 0.7, 1])
        e.particlePositionRange = CGVector(dx: size.width, dy: 0)
        e.position = CGPoint(x: size.width / 2, y: -20)
        e.targetNode = self
        addChild(e)
        e.run(.sequence([.wait(forDuration: 5), .removeFromParent()]))
    }

    /// Confetti falling from the top of the screen.
    func confetti() {
        guard !reduceMotion else { return }
        let colors: [SKColor] = [SKColor(Color.gameCyan), SKColor(Color.gameGold), SKColor(Color.gameMagenta), SKColor(Color.gameCoral), .white]
        for (index, color) in colors.enumerated() {
            let e = SKEmitterNode()
            e.particleTexture = SKTexture(image: Self.chip)
            e.numParticlesToEmit = 26
            e.particleBirthRate = 60
            e.particleLifetime = 3.2
            e.particleLifetimeRange = 0.8
            e.emissionAngle = -.pi / 2
            e.emissionAngleRange = 0.5
            e.particleSpeed = 160
            e.particleSpeedRange = 90
            e.yAcceleration = -160
            e.xAcceleration = index.isMultiple(of: 2) ? 20 : -20
            e.particleRotationSpeed = 5
            e.particleRotationRange = .pi * 2
            e.particleScale = 1
            e.particleScaleRange = 0.4
            e.particleColor = color
            e.particleColorBlendFactor = 1
            e.particlePositionRange = CGVector(dx: size.width, dy: 0)
            e.position = CGPoint(x: size.width / 2, y: size.height + 10)
            e.targetNode = self
            addChild(e)
            e.run(.sequence([.wait(forDuration: 4.5), .removeFromParent()]))
        }

        // The kit's ribbons tumbling through the chips.
        let ribbons = SKEmitterNode()
        ribbons.particleTexture = props.textureNamed(GameArt.Props.ribbon)
        ribbons.numParticlesToEmit = 18
        ribbons.particleBirthRate = 9
        ribbons.particleLifetime = 3.6
        ribbons.emissionAngle = -.pi / 2
        ribbons.emissionAngleRange = 0.4
        ribbons.particleSpeed = 130
        ribbons.particleSpeedRange = 60
        ribbons.yAcceleration = -120
        ribbons.particleRotationRange = .pi * 2
        ribbons.particleRotationSpeed = 3
        ribbons.particleScale = 0.4
        ribbons.particleScaleRange = 0.15
        ribbons.particlePositionRange = CGVector(dx: size.width, dy: 0)
        ribbons.position = CGPoint(x: size.width / 2, y: size.height + 20)
        ribbons.targetNode = self
        addChild(ribbons)
        ribbons.run(.sequence([.wait(forDuration: 5), .removeFromParent()]))
    }

    private static let chip: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 6)).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 6))
    }
}
