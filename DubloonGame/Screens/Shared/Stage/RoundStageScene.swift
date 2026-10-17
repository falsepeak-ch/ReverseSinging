//
//  RoundStageScene.swift
//  DubloonGame
//
//  The set behind a round: lights sweeping the stage, and the host watching from her booth.
//

import SpriteKit
import SwiftUI

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

/// The stage behind a round. Everything the player touches is SwiftUI on top of it; this
/// draws the set, its lights, and the host in a round booth window at the top right.
final class RoundStageScene: SKScene {

    var safeInsets = EdgeInsets() { didSet { if oldValue != safeInsets { layoutStage() } } }
    /// The height of the stage area, from the top of the screen. The deck covers the rest.
    var stageHeight: CGFloat = 400 { didSet { if oldValue != stageHeight { layoutStage() } } }

    private let reduceMotion: Bool
    private let backdrop = SKSpriteNode(imageNamed: GameArt.stage)
    private var beams: [SKSpriteNode] = []
    private let booth = SKNode()
    private let boothRing = SKShapeNode()
    private let boothGlass = SKShapeNode()
    private let crop = SKCropNode()
    private let mask = SKShapeNode()
    private let hostSprite: SKSpriteNode
    private let poses: [GameArt.Host: SKTexture]
    private var mood: HostMood = .idle
    private var boothDiameter: CGFloat = 130

    init(size: CGSize, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        let atlas = SKTextureAtlas(named: GameArt.hostAtlas)
        var poses: [GameArt.Host: SKTexture] = [:]
        for pose in GameArt.Host.allCases { poses[pose] = atlas.textureNamed(pose.rawValue) }
        self.poses = poses
        hostSprite = SKSpriteNode(texture: poses[.idle])
        // Her face, about a sixth of the way down the drawing, sits in the middle of the window.
        hostSprite.anchorPoint = CGPoint(x: 0.48, y: 0.8)
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

        // The booth: a porthole with a navy rim and a pale glass behind the host.
        boothGlass.fillColor = SKColor(red: 0.62, green: 0.86, blue: 0.97, alpha: 1)
        boothGlass.strokeColor = .clear
        mask.fillColor = .white
        crop.maskNode = mask
        crop.addChild(boothGlass)
        crop.addChild(hostSprite)
        boothRing.fillColor = .clear
        boothRing.strokeColor = SKColor(Color.gameIvory)
        boothRing.lineWidth = 9
        let rimLine = SKShapeNode()
        rimLine.name = "rim"
        rimLine.fillColor = .clear
        rimLine.strokeColor = SKColor(Color.gameNavy)
        rimLine.lineWidth = 3.5
        booth.addChild(crop)
        booth.addChild(boothRing)
        booth.addChild(rimLine)
        booth.zPosition = 5
        addChild(booth)
    }

    // MARK: - Layout

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutStage()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        layoutStage()
        startMotion()
        set(mood, force: true)
    }

    private func layoutStage() {
        guard size.width > 0 else { return }
        let w = size.width, h = size.height
        // The set is framed on the stage area, cropped rather than squashed.
        let art = backdrop.texture?.size() ?? size
        let fill = max(w / art.width, stageHeight / art.height) * 1.08
        backdrop.size = CGSize(width: art.width * fill, height: art.height * fill)
        backdrop.position = CGPoint(x: w / 2, y: h - stageHeight / 2 + stageHeight * 0.1)

        for (index, beam) in beams.enumerated() {
            beam.size = CGSize(width: w * 0.8, height: stageHeight * 1.1)
            beam.position = CGPoint(x: index == 0 ? w * 0.22 : w * 0.78, y: h)
        }

        boothDiameter = min(w * 0.34, 150)
        let r = boothDiameter / 2
        let circle = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: boothDiameter, height: boothDiameter), transform: nil)
        mask.path = circle
        boothGlass.path = circle
        boothRing.path = circle
        (booth.childNode(withName: "rim") as? SKShapeNode)?.path = CGPath(
            ellipseIn: CGRect(x: -r - 4.5, y: -r - 4.5, width: boothDiameter + 9, height: boothDiameter + 9),
            transform: nil
        )
        // Head and shoulders in the window.
        let texture = poses[.idle]?.size() ?? CGSize(width: 1, height: 1)
        hostSprite.setScale(boothDiameter * 2.6 / texture.height)
        hostSprite.position = CGPoint(x: 0, y: -r * 0.12)
        booth.position = CGPoint(x: w - r - 14, y: h - stageHeight + r + 18)
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
        let bob = SKAction.sequence([.moveBy(x: 0, y: 3, duration: 1.3), .moveBy(x: 0, y: -3, duration: 1.3)])
        bob.timingMode = .easeInEaseOut
        hostSprite.run(.repeatForever(bob), withKey: "bob")
    }

    // MARK: - Mood

    func set(_ newMood: HostMood, force: Bool = false) {
        guard force || newMood != mood else { return }
        mood = newMood
        hostSprite.removeAction(forKey: "pose")
        booth.removeAction(forKey: "react")
        guard let idle = poses[.idle] else { return }

        switch newMood {
        case .idle:
            hostSprite.texture = idle
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
                booth.run(.sequence([.scale(to: 1.06, duration: 0.15), .scale(to: 1, duration: 0.2)]), withKey: "react")
            }
        case .cheering:
            hostSprite.texture = poses[.delight] ?? idle
            guard !reduceMotion else { return }
            let hop = SKAction.sequence([
                .moveBy(x: 0, y: 14, duration: 0.12), .moveBy(x: 0, y: -14, duration: 0.14),
            ])
            booth.run(.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1, duration: 0.2)]), withKey: "react")
            hostSprite.run(.repeat(hop, count: 3), withKey: "pose")
        case .wincing:
            hostSprite.texture = poses[.blink] ?? idle
            guard !reduceMotion else { return }
            let shake = SKAction.sequence([
                .moveBy(x: -6, y: 0, duration: 0.05), .moveBy(x: 12, y: 0, duration: 0.08),
                .moveBy(x: -10, y: 0, duration: 0.07), .moveBy(x: 4, y: 0, duration: 0.05),
            ])
            booth.run(shake, withKey: "react")
            hostSprite.run(.sequence([.wait(forDuration: 0.9), .setTexture(idle)]), withKey: "pose")
        }
    }
}

/// A clear layer over the whole round for stars and confetti, so they fly over the cards and
/// the picture rather than behind them.
final class RoundFXScene: SKScene {
    private let reduceMotion: Bool
    private lazy var star = SKTextureAtlas(named: GameArt.UI.atlas).textureNamed(GameArt.UI.star)

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
    }

    private static let chip: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 6)).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 6))
    }
}
