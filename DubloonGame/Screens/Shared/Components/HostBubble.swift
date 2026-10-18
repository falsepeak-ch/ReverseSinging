//
//  HostBubble.swift
//  DubloonGame
//
//  The host's speech bubble: types her line out, with its tail pointing at her.
//

import SwiftUI

/// What the host is saying, in an ivory bubble drawn like the kit's panels.
///
/// The line types itself out at a talking pace and reports while it does, so the host's mouth
/// moves for as long as she is "speaking". A new line replaces the old one with a pop. With
/// Reduce Motion the line appears whole.
struct HostBubble: View {
    let text: String
    /// Which side of the bubble the tail sticks out of: towards the host.
    var tail: Edge = .bottom
    /// Where along that side the tail sits, 0...1.
    var tailPosition: CGFloat = 0.5
    var onTalkingChange: (Bool) -> Void = { _ in }

    @State private var shown = 0
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let charactersPerSecond = 42.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The whole line, laid out but clear, so the bubble is its final size from the
            // first letter and words never jump between lines.
            Text(text).opacity(0)
            Text(text.prefix(shown))
        }
        .font(.game(18, weight: .bold))
        .foregroundStyle(Color.gameNavy)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            ZStack {
                BubbleShape(tail: tail, tailPosition: tailPosition)
                    .fill(Color.gameNavy)
                    .offset(y: 5)
                BubbleShape(tail: tail, tailPosition: tailPosition)
                    .fill(Color.gameIvory)
                BubbleShape(tail: tail, tailPosition: tailPosition)
                    .stroke(Color.gameNavy, style: StrokeStyle(lineWidth: 3.5, lineJoin: .round))
            }
        }
        .padding(tail == .bottom ? .bottom : (tail == .trailing ? .trailing : .leading), 14)
        .scaleEffect(pop ? 1 : 0.85, anchor: anchor)
        .opacity(pop ? 1 : 0)
        .task(id: text) { await type() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var anchor: UnitPoint {
        switch tail {
        case .bottom: UnitPoint(x: tailPosition, y: 1)
        case .trailing: UnitPoint(x: 1, y: tailPosition)
        case .leading: UnitPoint(x: 0, y: tailPosition)
        case .top: UnitPoint(x: tailPosition, y: 0)
        }
    }

    private func type() async {
        pop = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pop = true }
        UIAccessibility.post(notification: .announcement, argument: text)
        guard !reduceMotion else {
            shown = text.count
            return
        }
        shown = 0
        onTalkingChange(true)
        defer { onTalkingChange(false) }
        for index in 1...max(text.count, 1) {
            try? await Task.sleep(for: .seconds(1 / charactersPerSecond))
            if Task.isCancelled { return }
            shown = index
        }
    }
}

/// A rounded box with a pointed tail on one side.
nonisolated struct BubbleShape: Shape {
    var tail: Edge
    var tailPosition: CGFloat
    var radius: CGFloat = 20
    var tailSize: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        var tailPath = Path()
        switch tail {
        case .bottom:
            let x = rect.minX + max(radius + tailSize, min(rect.width - radius - tailSize, rect.width * tailPosition))
            tailPath.move(to: CGPoint(x: x - tailSize, y: rect.maxY - 1))
            tailPath.addLine(to: CGPoint(x: x + tailSize * 0.2, y: rect.maxY + tailSize))
            tailPath.addLine(to: CGPoint(x: x + tailSize, y: rect.maxY - 1))
        case .trailing:
            let y = rect.minY + max(radius + tailSize, min(rect.height - radius - tailSize, rect.height * tailPosition))
            tailPath.move(to: CGPoint(x: rect.maxX - 1, y: y - tailSize))
            tailPath.addLine(to: CGPoint(x: rect.maxX + tailSize, y: y + tailSize * 0.2))
            tailPath.addLine(to: CGPoint(x: rect.maxX - 1, y: y + tailSize))
        case .leading:
            let y = rect.minY + max(radius + tailSize, min(rect.height - radius - tailSize, rect.height * tailPosition))
            tailPath.move(to: CGPoint(x: rect.minX + 1, y: y - tailSize))
            tailPath.addLine(to: CGPoint(x: rect.minX - tailSize, y: y + tailSize * 0.2))
            tailPath.addLine(to: CGPoint(x: rect.minX + 1, y: y + tailSize))
        case .top:
            let x = rect.minX + rect.width * tailPosition
            tailPath.move(to: CGPoint(x: x - tailSize, y: rect.minY + 1))
            tailPath.addLine(to: CGPoint(x: x, y: rect.minY - tailSize))
            tailPath.addLine(to: CGPoint(x: x + tailSize, y: rect.minY + 1))
        }
        tailPath.closeSubpath()
        // One outline, so the stroke has no seam where the tail meets the box.
        path = Path(path.cgPath.union(tailPath.cgPath))
        return path
    }
}
