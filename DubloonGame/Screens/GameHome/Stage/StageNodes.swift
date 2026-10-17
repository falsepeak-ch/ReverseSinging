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
        var font = StageText.font(size: pointSize, weight: weight)
        var width = (text as NSString).size(withAttributes: [.font: font]).width
        while width > maxWidth, pointSize > size * 0.66 {
            pointSize -= 0.5
            font = StageText.font(size: pointSize, weight: weight)
            width = (text as NSString).size(withAttributes: [.font: font]).width
        }

        let line = max(pointSize * 0.14, 2)
        let lip = max(pointSize * 0.08, 1.5)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let canvas = CGSize(width: ceil(textSize.width + line * 2 + 2), height: ceil(textSize.height + line * 2 + lip + 2))
        let origin = CGPoint(x: line + 1, y: line + 1)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
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

/// The kit's cyan pill with a label on it.
final class PillButton: StageButton {
    private let pill: NineSliceNode
    private let label = OutlinedTextNode()
    private var title: String
    private var fontSize: CGFloat

    init(title: String, ui: SKTextureAtlas, fontSize: CGFloat = 18) {
        self.title = title
        self.fontSize = fontSize
        pill = NineSliceNode(
            texture: ui.textureNamed(GameArt.UI.button),
            centerRect: CGRect(x: 0.34, y: 0.3, width: 0.32, height: 0.4)
        )
        super.init()
        pill.spriteShader = StageShaders.shine()
        addChild(pill)
        label.position.y = 2
        label.zPosition = 1
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    func setTitle(_ title: String, fontSize: CGFloat = 18) {
        self.title = title
        self.fontSize = fontSize
    }

    /// The pill's width follows its title unless one is given.
    func layout(width: CGFloat? = nil, height: CGFloat = 56) {
        let w = width ?? 240
        label.set(title, size: fontSize, color: .white, maxWidth: w - 36)
        pill.size = CGSize(width: w, height: height)
        hitSize = CGSize(width: w, height: height + 8)
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

/// A game on the stage: its icon bobbing over a pill with its name.
final class GameTileButton: StageButton {
    /// Big enough for a thumb, as on a game's title screen.
    static let pillHeight: CGFloat = 64
    static let titleSize: CGFloat = 21

    let mode: GameMode
    private let icon: SKSpriteNode
    private let pill: PillButton

    init(mode: GameMode, games: SKTextureAtlas, ui: SKTextureAtlas) {
        self.mode = mode
        icon = SKSpriteNode(texture: games.textureNamed(GameArt.tile(for: mode)))
        pill = PillButton(title: mode.title, ui: ui, fontSize: GameTileButton.titleSize)
        super.init()
        // The pill is a part of this button, not a button of its own.
        pill.isUserInteractionEnabled = false
        addChild(icon)
        addChild(pill)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Lays the tile out in a `width`-wide column, its icon centred on this node.
    func layout(width: CGFloat, phase: Double) {
        let iconSide = width * 0.82
        let base = icon.texture?.size() ?? CGSize(width: 1, height: 1)
        let scale = iconSide / max(base.width, base.height)
        icon.setScale(scale)
        pill.layout(width: width, height: GameTileButton.pillHeight)
        pill.position.y = -iconSide / 2 - GameTileButton.pillHeight / 2 + 4
        hitSize = CGSize(width: width, height: iconSide + GameTileButton.pillHeight + 16)

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
