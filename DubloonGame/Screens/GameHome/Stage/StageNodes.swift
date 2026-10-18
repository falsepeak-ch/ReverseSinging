//
//  StageNodes.swift
//  DubloonGame
//
//  The pieces of the stage: labels, the nine-sliced panel and button, buttons that press.
//

import SpriteKit
import SwiftUI

// MARK: - Labels

enum StageText {
    /// A plain multi-line label in the game's chunky rounded type, for running text.
    static func label(
        _ text: String,
        size: CGFloat,
        weight: UIFont.Weight = .heavy,
        color: SKColor = SKColor(Color.gameNavy),
        maxWidth: CGFloat? = nil
    ) -> SKLabelNode {
        let node = SKLabelNode()
        node.numberOfLines = 0
        node.preferredMaxLayoutWidth = maxWidth ?? 0
        node.horizontalAlignmentMode = .center
        node.verticalAlignmentMode = .center
        node.attributedText = attributed(text, size: size, weight: weight, color: color)
        return node
    }

    static func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
    }

    static func attributed(
        _ text: String,
        size: CGFloat,
        weight: UIFont.Weight = .heavy,
        color: SKColor
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [
            .font: font(size: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }
}

/// One line of display type with a navy outline and a lip under it, like the lettering on
/// the kit's art.
///
/// Drawn into a texture rather than with `SKLabelNode`, which measures stroked text without
/// its stroke and clips it. A line too long for `maxWidth` is set smaller, down to two
/// thirds of its size, rather than wrapped onto a button.
final class OutlinedTextNode: SKSpriteNode {
    func set(
        _ text: String,
        size: CGFloat,
        weight: UIFont.Weight = .heavy,
        color: SKColor,
        outline: SKColor = SKColor(Color.gameNavy),
        maxWidth: CGFloat = .greatestFiniteMagnitude
    ) {
        var pointSize = size
        var font = GameFont.display(size: pointSize)
        var width = (text as NSString).size(withAttributes: [.font: font]).width
        while width > maxWidth, pointSize > size * 0.66 {
            pointSize -= 0.5
            font = GameFont.display(size: pointSize)
            width = (text as NSString).size(withAttributes: [.font: font]).width
        }

        let line = max(pointSize * 0.14, 2)
        let lip = max(pointSize * 0.08, 1.5)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let canvas = CGSize(width: ceil(textSize.width + line * 2 + 2), height: ceil(textSize.height + line * 2 + lip + 2))
        let origin = CGPoint(x: line + 1, y: line + 1)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            // Round joins: the display face's sharp corners would otherwise grow miter spikes.
            context.cgContext.setLineJoin(.round)
            // The stroke is centred on the glyph edge; drawn first and twice as wide, only its
            // outer half shows once the fill goes on top.
            let stroke: [NSAttributedString.Key: Any] = [
                .font: font, .strokeColor: outline, .strokeWidth: line * 2 / pointSize * 100,
            ]
            (text as NSString).draw(at: CGPoint(x: origin.x, y: origin.y + lip), withAttributes: stroke)
            (text as NSString).draw(at: CGPoint(x: origin.x, y: origin.y + lip), withAttributes: [.font: font, .foregroundColor: outline])
            (text as NSString).draw(at: origin, withAttributes: stroke)
            (text as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: color])
        }
        texture = SKTexture(image: image)
        self.size = canvas
    }
}

// MARK: - Nine-slice

/// A sprite stretched to any size while its corners keep theirs. The stretch is done with
/// scale, so anything drawn on top lives beside it, not inside it.
final class NineSliceNode: SKNode {
    private let sprite: SKSpriteNode

    init(texture: SKTexture, centerRect: CGRect) {
        sprite = SKSpriteNode(texture: texture)
        sprite.centerRect = centerRect
        super.init()
        addChild(sprite)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    var size: CGSize = .zero {
        didSet {
            let base = sprite.texture?.size() ?? CGSize(width: 1, height: 1)
            sprite.xScale = max(size.width, base.width * 0.5) / base.width
            sprite.yScale = max(size.height, base.height * 0.5) / base.height
        }
    }

    var spriteShader: SKShader? {
        get { sprite.shader }
        set { sprite.shader = newValue }
    }
}

// MARK: - Buttons

/// A node that behaves as a game button: it squashes under the finger, springs back on
/// release, and only fires when the finger is lifted over it.
class StageButton: SKNode {
    var onTap: (() -> Void)?
    /// Where touches count, in this node's coordinates.
    var hitSize: CGSize = .zero

    private var isPressed = false
    private var restingScale: CGFloat = 1

    override init() {
        super.init()
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    private func contains(_ touch: UITouch) -> Bool {
        let p = touch.location(in: self)
        return abs(p.x) <= hitSize.width / 2 && abs(p.y) <= hitSize.height / 2
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, contains(touch) else { return }
        isPressed = true
        restingScale = xScale == 0 ? 1 : xScale
        removeAction(forKey: "press")
        let press = SKAction.scale(to: restingScale * 0.9, duration: 0.08)
        press.timingMode = .easeOut
        run(press, withKey: "press")
        HapticManager.shared.soft()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isPressed, let touch = touches.first else { return }
        let inside = contains(touch)
        let target = inside ? restingScale * 0.9 : restingScale
        if abs(xScale - target) > 0.001, action(forKey: "press") == nil {
            run(.scale(to: target, duration: 0.08), withKey: "press")
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isPressed, let touch = touches.first else { return }
        isPressed = false
        let fired = contains(touch)
        removeAction(forKey: "press")
        run(StageButton.springBack(to: restingScale), withKey: "press")
        if fired { onTap?() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isPressed = false
        removeAction(forKey: "press")
        run(.scale(to: restingScale, duration: 0.12), withKey: "press")
    }

    /// Overshoots and settles, the way a cartoon button pops back.
    static func springBack(to scale: CGFloat) -> SKAction {
        let up = SKAction.scale(to: scale * 1.08, duration: 0.1)
        up.timingMode = .easeOut
        let settle = SKAction.scale(to: scale, duration: 0.14)
        settle.timingMode = .easeInEaseOut
        return .sequence([up, settle])
    }
}

/// The kit's cyan pill with a label on it, optionally repainted (`tint`) and led by a small
/// picture.
final class PillButton: StageButton {
    private let pill: NineSliceNode
    private let label = OutlinedTextNode()
    private var icon: SKSpriteNode?
    private var title: String
    private var fontSize: CGFloat

    init(title: String, ui: SKTextureAtlas, fontSize: CGFloat = 18, tint: SKColor? = nil, icon: SKTexture? = nil) {
        self.title = title
        self.fontSize = fontSize
        pill = NineSliceNode(
            texture: ui.textureNamed(GameArt.UI.button),
            centerRect: CGRect(x: 0.34, y: 0.3, width: 0.32, height: 0.4)
        )
        super.init()
        pill.spriteShader = tint.map(StageShaders.tintedShine) ?? StageShaders.shine()
        addChild(pill)
        label.position.y = 2
        label.zPosition = 1
        addChild(label)
        if let icon {
            let sprite = SKSpriteNode(texture: icon)
            sprite.zPosition = 2
            self.icon = sprite
            addChild(sprite)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    func setTitle(_ title: String, fontSize: CGFloat = 18) {
        self.title = title
        self.fontSize = fontSize
    }

    /// The pill's width follows its title unless one is given.
    func layout(width: CGFloat? = nil, height: CGFloat = 56) {
        let w = width ?? 240
        // The picture breaks out of the pill's left end, a little bigger than the pill is tall.
        let iconSide = height * 1.25
        let iconRoom = icon == nil ? 0 : iconSide * 0.55
        label.set(title, size: fontSize, color: .white, maxWidth: w - 36 - iconRoom)
        label.position.x = iconRoom / 2
        pill.size = CGSize(width: w, height: height)
        hitSize = CGSize(width: w, height: height + 8)
        if let icon, let base = icon.texture?.size() {
            icon.setScale(iconSide / max(base.width, base.height))
            icon.position = CGPoint(x: -w / 2 + iconSide * 0.38, y: 4)
            if icon.action(forKey: "wiggle") == nil {
                let wiggle = SKAction.sequence([
                    .wait(forDuration: 2.4),
                    .rotate(toAngle: 0.18, duration: 0.08), .rotate(toAngle: -0.14, duration: 0.1),
                    .rotate(toAngle: 0.08, duration: 0.08), .rotate(toAngle: 0, duration: 0.1),
                ])
                icon.run(.repeatForever(wiggle), withKey: "wiggle")
            }
        }
    }
}

/// A round ivory button with a symbol, for the stage's corners.
final class RoundIconButton: StageButton {
    init(symbol: String, diameter: CGFloat = 56) {
        super.init()
        let disc = SKShapeNode(circleOfRadius: diameter / 2)
        disc.fillColor = SKColor(Color.gameIvory)
        disc.strokeColor = SKColor(Color.gameNavy)
        disc.lineWidth = 3.5
        let lip = SKShapeNode(circleOfRadius: diameter / 2)
        lip.fillColor = SKColor(Color.gameNavy)
        lip.strokeColor = .clear
        lip.position.y = -3
        addChild(lip)
        addChild(disc)

        let config = UIImage.SymbolConfiguration(pointSize: diameter * 0.42, weight: .heavy)
        if let image = UIImage(systemName: symbol, withConfiguration: config)?
            .withTintColor(UIColor(Color.gameNavy), renderingMode: .alwaysOriginal) {
            let icon = SKSpriteNode(texture: SKTexture(image: image))
            icon.zPosition = 1
            addChild(icon)
        }
        hitSize = CGSize(width: diameter + 12, height: diameter + 12)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }
}

/// A game on the stage: its icon bobbing in a lit glass cabinet, a pill with its name across
/// the cabinet's foot, and a badge for how far you have got.
final class GameTileButton: StageButton {
    /// Big enough for a thumb, as on a game's title screen.
    static let pillHeight: CGFloat = 64
    static let titleSize: CGFloat = 21

    let mode: GameMode
    private let icon: SKSpriteNode
    private let pill: PillButton
    private let cabinet = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
    private let badge = SKNode()
    private let seed: Float

    init(mode: GameMode, games: SKTextureAtlas, ui: SKTextureAtlas, seed: Float) {
        self.mode = mode
        self.seed = seed
        icon = SKSpriteNode(texture: games.textureNamed(GameArt.tile(for: mode)))
        pill = PillButton(title: mode.title, ui: ui, fontSize: GameTileButton.titleSize)
        super.init()
        // The pill is a part of this button, not a button of its own.
        pill.isUserInteractionEnabled = false
        cabinet.zPosition = -1
        icon.zPosition = 1
        pill.zPosition = 2
        badge.zPosition = 3
        addChild(cabinet)
        addChild(icon)
        addChild(pill)
        addChild(badge)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    /// How tall the tile stands above and below its centre, for the scene's layout.
    static func extent(width: CGFloat) -> (above: CGFloat, below: CGFloat) {
        let iconSide = width * 0.74
        return (iconSide / 2 + 22, iconSide / 2 + pillHeight - 4)
    }

    /// A small label in the cabinet's corner, such as the stars won; nil clears it.
    func setBadge(_ text: String?, star: SKTexture?) {
        badge.removeAllChildren()
        guard let text else { return }
        let label = OutlinedTextNode()
        label.set(text, size: 15, weight: .black, color: SKColor(Color.gameGold))
        let starSide: CGFloat = star == nil ? 0 : 20
        let width = label.size.width + starSide + 18
        let capsule = SKShapeNode(rectOf: CGSize(width: width, height: 30), cornerRadius: 15)
        capsule.fillColor = SKColor(Color.gameNavy)
        capsule.strokeColor = SKColor(Color.gameGold)
        capsule.lineWidth = 2
        badge.addChild(capsule)
        label.position.x = starSide / 2
        label.zPosition = 1
        badge.addChild(label)
        if let star {
            let sprite = SKSpriteNode(texture: star)
            sprite.size = CGSize(width: starSide, height: starSide * star.size().height / max(star.size().width, 1))
            sprite.position.x = -width / 2 + 9 + starSide / 2
            sprite.zPosition = 1
            badge.addChild(sprite)
        }
        badge.userData = ["width": width]
        layoutBadge()
    }

    private var lastWidth: CGFloat = 0

    private func layoutBadge() {
        let badgeWidth = badge.userData?["width"] as? CGFloat ?? 0
        let iconSide = lastWidth * 0.74
        badge.position = CGPoint(x: lastWidth / 2 - badgeWidth / 2 - 4, y: iconSide / 2 + 16)
    }

    /// Lays the tile out in a `width`-wide column, its icon centred on this node.
    func layout(width: CGFloat, phase: Double) {
        lastWidth = width
        let iconSide = width * 0.74
        let base = icon.texture?.size() ?? CGSize(width: 1, height: 1)
        let scale = iconSide / max(base.width, base.height)
        icon.setScale(scale)
        pill.layout(width: width, height: GameTileButton.pillHeight)
        pill.position.y = -iconSide / 2 - GameTileButton.pillHeight / 2 + 4

        let cabinetHeight = iconSide + 52
        cabinet.size = CGSize(width: width, height: cabinetHeight)
        cabinet.position.y = (iconSide / 2 + 22) - cabinetHeight / 2
        if cabinet.shader == nil {
            cabinet.shader = StageShaders.cabinet(
                rim: SKColor(mode == .imitate ? Color.gameCoral : Color.gameCyan),
                aspect: Float(width / cabinetHeight),
                seed: seed
            )
        } else {
            cabinet.shader?.uniformNamed("u_aspect")?.floatValue = Float(width / cabinetHeight)
        }
        hitSize = CGSize(width: width, height: iconSide + GameTileButton.pillHeight + 30)
        layoutBadge()

        icon.removeAllActions()
        let bob = SKAction.sequence([
            .moveTo(y: 6, duration: 1.1),
            .moveTo(y: -2, duration: 1.1),
        ])
        bob.timingMode = .easeInEaseOut
        let tilt = SKAction.sequence([
            .rotate(toAngle: 0.04, duration: 1.6),
            .rotate(toAngle: -0.04, duration: 1.6),
        ])
        icon.run(.sequence([.wait(forDuration: phase), .group([.repeatForever(bob), .repeatForever(tilt)])]))
    }
}

// MARK: - HUD

/// The stars won so far, in a navy capsule in the stage's top corner, like a game's coin
/// counter. It bumps when the count goes up.
final class StarCounterNode: SKNode {
    private let capsule = SKShapeNode()
    private let star: SKSpriteNode
    private let label = OutlinedTextNode()
    private var shown = -1
    private(set) var width: CGFloat = 96

    init(star texture: SKTexture) {
        star = SKSpriteNode(texture: texture)
        super.init()
        capsule.fillColor = SKColor(Color.gameNavy)
        capsule.strokeColor = SKColor(Color.gameGold)
        capsule.lineWidth = 3
        addChild(capsule)
        star.zPosition = 1
        addChild(star)
        label.zPosition = 1
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    func set(stars: Int, of total: Int) {
        guard stars != shown else { return }
        let grew = shown >= 0 && stars > shown
        shown = stars
        label.set("\(stars)", size: 22, weight: .black, color: .white)
        let starSide: CGFloat = 38
        star.size = CGSize(width: starSide, height: starSide)
        width = max(label.size.width + starSide + 26, 92)
        capsule.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -24, width: width, height: 48),
            cornerWidth: 24, cornerHeight: 24, transform: nil
        )
        star.position = CGPoint(x: -width / 2 + 8 + starSide / 2, y: 1)
        label.position = CGPoint(x: star.position.x + starSide / 2 + 4 + label.size.width / 2, y: 0)
        if grew {
            star.run(.sequence([.scale(to: 1.4, duration: 0.12), .scale(to: 1, duration: 0.2)]))
        }
    }
}
