//
//  GameStageScene.swift
//  DubloonGame
//
//  The home stage as a SpriteKit scene: lights, host, speech panel, the games, sparkles.
//

import SpriteKit
import SwiftUI

/// What the stage shows, handed down from SwiftUI on every change.
struct StageState: Equatable {
    var hostLine: String
    /// Nil when Dubloon Pro is owned: no offer on the stage.
    var proTitle: String?
    /// The free takes have run out: the host is taken aback.
    var isOutOfTakes = false
    /// Stars won across the sound imitation round, and how many there are to win.
    var stars = 0
    var maxStars = 0
}

/// The home stage.
///
/// SpriteKit draws it so it can behave as a game: GPU-shaded spotlights sweeping the set, a
/// host animated from the kit's frames, a speech panel that types, buttons that squash and
/// pop, and particles. Navigation stays in SwiftUI; the scene reports taps through closures.
///
/// Layout runs bottom-up from the safe area: the Pro pill, the games, the speech panel, and
/// the host standing behind it in whatever height is left under the title.
final class GameStageScene: SKScene {

    var onSelectGame: ((GameMode) -> Void)?
    var onPro: (() -> Void)?
    var onSettings: (() -> Void)?
    var onLeaderboards: (() -> Void)?

    /// The view's safe area, which SpriteKit does not know about.
    var safeInsets = EdgeInsets() { didSet { if oldValue != safeInsets { layoutStage() } } }

    private let reduceMotion: Bool
    private let propsAtlas = SKTextureAtlas(named: GameArt.Props.atlas)
    private let uiAtlas = SKTextureAtlas(named: GameArt.UI.atlas)
    private let gamesAtlas = SKTextureAtlas(named: GameArt.gamesAtlas)

    private let backdrop = SKSpriteNode(imageNamed: GameArt.stage)
    private var beams: [SKSpriteNode] = []
    private let floorGlow = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
    private lazy var host = HostNode(reduceMotion: reduceMotion)
    private lazy var dialogue = DialogueNode(ui: uiAtlas)
    private lazy var tiles = GameHomeViewModel.games.enumerated().map { index, mode in
        GameTileButton(mode: mode, games: gamesAtlas, ui: uiAtlas, seed: Float(index) * 0.5)
    }
    private lazy var proPill = PillButton(
        title: "", ui: uiAtlas, fontSize: 21,
        tint: SKColor(Color.gameGold),
        icon: propsAtlas.textureNamed(GameArt.Props.prize)
    )
    private lazy var starCounter = StarCounterNode(star: SKTexture(imageNamed: GameArt.Rating.filled))
    private let settingsButton = RoundIconButton(symbol: "gearshape.fill")
    private let titleNode = SKNode()
    private var ambientSparkles: SKEmitterNode?
    private var notes: SKEmitterNode?
    private var twinkles: [SKSpriteNode] = []

    private var state = StageState(hostLine: "", proTitle: nil)
    private var hasSpoken = false
    /// She waves the first time the stage is shown, not every time a game is closed.
    private var hasGreeted = false
    private var lastUpdate: TimeInterval?
    private var isBusy = false
    /// The title's natural width, so it can be scaled down beside the settings key.
    private var titleWidth: CGFloat = 1

    init(size: CGSize, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SKColor(Color.gameNavy)
        build()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Building

    private func build() {
        backdrop.zPosition = -10
        addChild(backdrop)

        // Two lamps crossing over the stage, warm and cool, swept slowly.
        let lamps: [(SKColor, Float)] = [
            (SKColor(Color.gameCyan), 0.6),
            (SKColor(red: 1, green: 0.86, blue: 0.62, alpha: 1), 0.5),
        ]
        for (index, lamp) in lamps.enumerated() {
            let beam = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
            beam.anchorPoint = CGPoint(x: 0.5, y: 1)
            beam.shader = StageShaders.beam(color: lamp.0, strength: lamp.1, seed: Float(index) * 0.37)
            beam.blendMode = .add
            beam.zPosition = -5
            beams.append(beam)
            addChild(beam)
        }

        floorGlow.shader = StageShaders.glow(color: SKColor(Color.gameCyan), strength: 0.55)
        floorGlow.blendMode = .add
        floorGlow.zPosition = -4
        addChild(floorGlow)

        host.zPosition = 0
        addChild(host)

        dialogue.zPosition = 10
        addChild(dialogue)

        for tile in tiles {
            tile.zPosition = 20
            tile.onTap = { [weak self, weak tile] in
                guard let tile else { return }
                self?.select(tile.mode, from: tile)
            }
            addChild(tile)
        }

        proPill.zPosition = 20
        proPill.onTap = { [weak self] in self?.tappedPro() }
        addChild(proPill)

        settingsButton.zPosition = 30
        settingsButton.onTap = { [weak self] in
            GameSFX.play(.tap)
            self?.onSettings?()
        }
        addChild(settingsButton)

        starCounter.zPosition = 30
        starCounter.onTap = { [weak self] in
            GameSFX.play(.tap)
            self?.onLeaderboards?()
        }
        addChild(starCounter)

        let name = OutlinedTextNode()
        name.set("Dubloon", size: 42, weight: .black, color: SKColor(Color.gameIvory))
        let tag = OutlinedTextNode()
        tag.set(GameStrings.subtitle.uppercased(), size: 16, weight: .black, color: SKColor(Color.gameCyan))
        tag.position.y = -34
        titleWidth = max(name.size.width, tag.size.width)
        titleNode.addChild(name)
        titleNode.addChild(tag)
        titleNode.zPosition = 30
        addChild(titleNode)

        if !reduceMotion {
            let sparkles = Self.sparkles(texture: uiAtlas.textureNamed(GameArt.UI.star))
            sparkles.zPosition = 5
            sparkles.targetNode = self
            ambientSparkles = sparkles
            addChild(sparkles)

            let notes = Self.notes(texture: propsAtlas.textureNamed(GameArt.Props.note))
            notes.zPosition = -3
            notes.targetNode = self
            self.notes = notes
            addChild(notes)

            // The kit's four-frame sparkle, twinkling at a few points around the set.
            let frames = (0..<4).map { propsAtlas.textureNamed(GameArt.Props.sparkle($0)) }
            for index in 0..<5 {
                let twinkle = SKSpriteNode(texture: frames[0])
                twinkle.size = CGSize(width: 34, height: 34)
                twinkle.alpha = 0
                twinkle.blendMode = .add
                twinkle.zPosition = 6
                let animate = SKAction.animate(with: frames + frames.reversed(), timePerFrame: 0.09)
                twinkle.run(.repeatForever(.sequence([
                    .wait(forDuration: 1.2 + Double(index) * 0.7, withRange: 1.6),
                    .fadeIn(withDuration: 0.05),
                    animate,
                    .fadeOut(withDuration: 0.1),
                ])))
                twinkles.append(twinkle)
                addChild(twinkle)
            }
        }
    }

    // MARK: - State

    func apply(_ newState: StageState) {
        let lineChanged = newState.hostLine != state.hostLine
        let ranOut = newState.isOutOfTakes && !state.isOutOfTakes && !state.hostLine.isEmpty
        state = newState
        starCounter.set(stars: newState.stars, of: newState.maxStars)
        tiles.first { $0.mode == .imitate }?.setBadge(
            newState.maxStars > 0 ? "\(newState.stars)/\(newState.maxStars)" : nil,
            star: SKTexture(imageNamed: GameArt.Rating.filled)
        )
        if ranOut { host.surprise() }
        if let proTitle = newState.proTitle {
            proPill.setTitle(proTitle, fontSize: 21)
        }
        proPill.isHidden = newState.proTitle == nil
        if lineChanged { hasSpoken = false }
        layoutStage()
    }

    // MARK: - Layout

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutStage()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        host.startIdle(greeting: !hasGreeted)
        hasGreeted = true
        startLights()
        layoutStage()
    }

    private func layoutStage() {
        guard size.width > 0, size.height > 0, !state.hostLine.isEmpty else { return }
        let w = size.width, h = size.height
        let gutter: CGFloat = 16

        // The set fills the screen, cropped rather than squashed.
        let art = backdrop.texture?.size() ?? size
        let fill = max(w / art.width, h / art.height)
        backdrop.size = CGSize(width: art.width * fill, height: art.height * fill)
        backdrop.position = CGPoint(x: w / 2, y: h / 2)

        var y = safeInsets.bottom + 18

        if !proPill.isHidden {
            proPill.layout(width: min(w - gutter * 2, 380), height: 68)
            proPill.position = CGPoint(x: w / 2, y: y + 34)
            y += 68 + 14
        }

        let column = min((w - gutter * 3) / 2, 190)
        let extent = GameTileButton.extent(width: column)
        let tileCenterY = y + extent.below
        for (index, tile) in tiles.enumerated() {
            tile.layout(width: column, phase: Double(index) * 0.55)
            let x = w / 2 + (index == 0 ? -1 : 1) * (column / 2 + gutter / 2)
            tile.position = CGPoint(x: x, y: tileCenterY)
        }
        y = tileCenterY + extent.above + 14

        let panelWidth = min(w - gutter * 2, 420)
        dialogue.layout(width: panelWidth)
        // A new line is typed once; any later relayout only resizes the panel around it.
        if !hasSpoken {
            hasSpoken = true
            let typing = dialogue.say(state.hostLine, instantly: reduceMotion)
            if !isBusy { host.talk(for: typing) }
            popIn(dialogue)
        }
        let panelHeight = dialogue.panelSize.height
        dialogue.position = CGPoint(x: w / 2, y: y + panelHeight / 2)

        // The host stands behind the panel, which hides her below the knee.
        let feet = y + panelHeight * 0.3
        let titleBottom = h - safeInsets.top - 92
        let hostHeight = max(min(titleBottom - feet, h * 0.62), 160)
        host.layout(height: hostHeight)
        host.position = CGPoint(x: w / 2, y: feet)

        floorGlow.size = CGSize(width: w * 0.9, height: w * 0.35)
        floorGlow.position = CGPoint(x: w / 2, y: feet + 10)

        for (index, beam) in beams.enumerated() {
            beam.size = CGSize(width: w * 0.8, height: h * 0.85)
            // From the lamps painted into the top of the set.
            beam.position = CGPoint(x: index == 0 ? w * 0.27 : w * 0.73, y: h - h * 0.045)
        }

        titleNode.position = CGPoint(x: w / 2, y: h - safeInsets.top - 34)
        // Room between the settings key and its mirror on the left, so the two never touch on
        // a narrow phone.
        starCounter.isHidden = state.maxStars == 0
        let cornerWidth = max(starCounter.isHidden ? 0 : starCounter.width, 56)
        let titleRoom = w - 2 * (gutter + cornerWidth + 8)
        titleNode.setScale(min(1, titleRoom / titleWidth))
        settingsButton.position = CGPoint(x: w - gutter - 28, y: h - safeInsets.top - 30)
        starCounter.position = CGPoint(x: gutter + starCounter.width / 2, y: h - safeInsets.top - 30)

        if let sparkles = ambientSparkles {
            sparkles.position = CGPoint(x: w / 2, y: feet)
            sparkles.particlePositionRange = CGVector(dx: w, dy: 40)
        }
        if let notes {
            notes.position = CGPoint(x: w / 2, y: feet + hostHeight * 0.3)
            notes.particlePositionRange = CGVector(dx: w * 0.9, dy: hostHeight * 0.4)
        }
        // Around the host and the title, where the light catches.
        let spots: [CGPoint] = [
            CGPoint(x: w * 0.2, y: feet + hostHeight * 0.75),
            CGPoint(x: w * 0.8, y: feet + hostHeight * 0.55),
            CGPoint(x: w * 0.3, y: h - safeInsets.top - 70),
            CGPoint(x: w * 0.72, y: h - safeInsets.top - 20),
            CGPoint(x: w * 0.86, y: feet + hostHeight * 0.95),
        ]
        for (twinkle, spot) in zip(twinkles, spots) { twinkle.position = spot }
    }

    // MARK: - Motion

    private func startLights() {
        guard !reduceMotion else {
            beams.first?.zRotation = 0.18
            beams.last?.zRotation = -0.18
            return
        }
        for (index, beam) in beams.enumerated() {
            // Positive turns a hanging beam's foot to the right: the left lamp aims inwards.
            let direction: CGFloat = index == 0 ? 1 : -1
            beam.zRotation = direction * 0.1
            let out = SKAction.rotate(toAngle: direction * 0.32, duration: 3.4 + Double(index) * 0.7)
            out.timingMode = .easeInEaseOut
            let back = SKAction.rotate(toAngle: direction * 0.04, duration: 3.4 + Double(index) * 0.7)
            back.timingMode = .easeInEaseOut
            beam.run(.repeatForever(.sequence([out, back])), withKey: "sweep")
        }
    }

    private func popIn(_ node: SKNode) {
        guard !reduceMotion else { return }
        node.setScale(0.6)
        node.alpha = 0
        let grow = SKAction.scale(to: 1.05, duration: 0.16)
        grow.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.1)
        node.run(.group([.fadeIn(withDuration: 0.12), .sequence([grow, settle])]))
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate.map { min(currentTime - $0, 1.0 / 20) } ?? 0
        lastUpdate = currentTime
        dialogue.advance(by: delta)
    }

    // MARK: - Touches

    /// A tap anywhere that is not a button finishes the line being typed.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if dialogue.isTyping { dialogue.finish() }
    }

    private func select(_ mode: GameMode, from tile: SKNode) {
        guard !isBusy else { return }
        isBusy = true
        dialogue.finish()
        GameSFX.play(.select)
        HapticManager.shared.medium()
        burst(at: tile.position)
        host.cheer()
        // Timed on the scene rather than on the host's pose, which a new line can replace:
        // a completion inside that action could be dropped and leave every tile dead.
        run(.sequence([
            .wait(forDuration: HostNode.cheerDuration),
            .run { [weak self] in
                self?.isBusy = false
                self?.onSelectGame?(mode)
            },
        ]), withKey: "open")
    }

    private func tappedPro() {
        GameSFX.play(.coin)
        burst(at: proPill.position)
        onPro?()
    }

    // MARK: - Particles

    /// A handful of stars rising off the floor, always.
    private static func sparkles(texture: SKTexture) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = texture
        e.particleBirthRate = 5
        e.particleLifetime = 4.5
        e.particleLifetimeRange = 1.5
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.5
        e.particleSpeed = 40
        e.particleSpeedRange = 20
        e.particleScale = 0.35
        e.particleScaleRange = 0.2
        e.particleScaleSpeed = -0.05
        e.particleRotationSpeed = 1.2
        e.particleAlpha = 0
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.9, 0.9, 0], times: [0, 0.15, 0.7, 1])
        e.particleBlendMode = .add
        e.particleColorBlendFactor = 0.3
        e.particleColor = SKColor(Color.gameCyan)
        e.advanceSimulationTime(4)
        return e
    }

    /// Music notes drifting up off the stage, as if the set were playing.
    private static func notes(texture: SKTexture) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = texture
        e.particleBirthRate = 0.9
        e.particleLifetime = 5
        e.particleLifetimeRange = 1.5
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.4
        e.particleSpeed = 28
        e.particleSpeedRange = 12
        e.xAcceleration = 3
        e.particleScale = 0.32
        e.particleScaleRange = 0.12
        e.particleRotation = -0.2
        e.particleRotationRange = 0.6
        e.particleRotationSpeed = 0.3
        e.particleAlpha = 0
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.75, 0.75, 0], times: [0, 0.2, 0.7, 1])
        e.advanceSimulationTime(5)
        return e
    }

    /// A pop of stars where something was tapped.
    private func burst(at point: CGPoint) {
        guard !reduceMotion else { return }
        let e = SKEmitterNode()
        e.particleTexture = uiAtlas.textureNamed(GameArt.UI.star)
        e.numParticlesToEmit = 26
        e.particleBirthRate = 600
        e.particleLifetime = 0.9
        e.particleLifetimeRange = 0.3
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 260
        e.particleSpeedRange = 120
        e.yAcceleration = -420
        e.particleScale = 0.55
        e.particleScaleRange = 0.25
        e.particleScaleSpeed = -0.4
        e.particleRotationSpeed = 4
        e.particleAlphaSpeed = -0.9
        e.particleColorBlendFactor = 0.5
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [SKColor(Color.gameCyan), SKColor.white, SKColor(Color.gameCoral)],
            times: [0, 0.5, 1]
        )
        e.position = point
        e.zPosition = 40
        e.targetNode = self
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.6), .removeFromParent()]))
    }
}
