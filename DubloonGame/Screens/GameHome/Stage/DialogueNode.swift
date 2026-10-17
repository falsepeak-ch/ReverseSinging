//
//  DialogueNode.swift
//  DubloonGame
//
//  The host's speech panel, with the line typed out as she says it.
//

import SpriteKit
import SwiftUI

/// The ivory panel, nine-sliced around a line that types itself out.
///
/// The panel is sized for the whole line before typing starts, so it never grows under the
/// reader's eye. The typing is driven from the scene's frame clock (`advance`), not timers.
final class DialogueNode: SKNode {
    private let panelNode: NineSliceNode
    private let label: SKLabelNode
    private var line = ""
    private var shown = 0
    private var elapsed: TimeInterval = 0
    private let fontSize: CGFloat = 17

    /// Characters per second.
    private let charactersPerSecond: Double = 38

    private(set) var panelSize: CGSize = .zero
    private var width: CGFloat = 300

    init(ui: SKTextureAtlas) {
        panelNode = NineSliceNode(
            texture: ui.textureNamed(GameArt.UI.panel),
            centerRect: CGRect(x: 0.1, y: 0.26, width: 0.8, height: 0.5)
        )
        label = StageText.label("", size: 17, weight: .bold)
        super.init()
        addChild(panelNode)
        label.zPosition = 1
        label.position.y = 4
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    var isTyping: Bool { shown < line.count }

    /// Starts a new line, from its first letter unless `instantly`. Returns how long the
    /// typing will take.
    @discardableResult
    func say(_ text: String, instantly: Bool) -> TimeInterval {
        line = text
        shown = instantly ? text.count : 0
        elapsed = 0
        layout(width: width)
        return instantly ? 0 : Double(text.count) / charactersPerSecond
    }

    /// Sizes the panel for the whole line at `width`. Typing carries on where it was, so a
    /// relayout mid-line (the scene settling its size) does not skip to the end.
    func layout(width: CGFloat) {
        self.width = width
        label.preferredMaxLayoutWidth = width - 56
        // Measure the full line, then type into the space it needs.
        label.attributedText = attributed(line)
        let textHeight = label.frame.height
        panelSize = CGSize(width: width, height: max(textHeight + 52, 96))
        panelNode.size = panelSize
        render()
    }

    /// Skips to the end of the line.
    func finish() {
        shown = line.count
        render()
    }

    func advance(by delta: TimeInterval) {
        guard isTyping else { return }
        elapsed += delta
        let target = min(Int(elapsed * charactersPerSecond), line.count)
        if target != shown {
            shown = target
            render()
        }
    }

    private func render() {
        // The untyped rest is laid out but clear, so the words never jump between lines.
        let typed = String(line.prefix(shown))
        let rest = String(line.dropFirst(shown))
        let text = NSMutableAttributedString(attributedString: attributed(typed))
        text.append(StageText.attributed(rest, size: fontSize, weight: .bold, color: .clear))
        label.attributedText = text
    }

    private func attributed(_ text: String) -> NSAttributedString {
        StageText.attributed(text, size: fontSize, weight: .bold, color: SKColor(Color.gameNavy))
    }
}
