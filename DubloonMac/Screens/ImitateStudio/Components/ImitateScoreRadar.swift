//
//  ImitateScoreRadar.swift
//  DubloonMac
//
//  The parts of an imitation's score as a radar plot
//

import SwiftUI
import DubScoring

/// Rhythm, pitch, tone and length on their own axes, the attempt drawn as the shape they make.
/// A good copy is a large even shape; a lopsided one says at a glance which part let it down.
/// Pitch has no axis for sounds without a note to follow.
struct ImitateScoreRadar: View {
    let score: ImitationScore

    private var axes: [(label: String, value: Double)] {
        var axes: [(String, Double)] = [(Strings.Imitate.Part.rhythm, score.rhythm)]
        if let pitch = score.pitch { axes.append((Strings.Imitate.Part.pitch, pitch)) }
        axes.append((Strings.Imitate.Part.tone, score.tone))
        axes.append((Strings.Imitate.Part.duration, score.duration))
        return axes
    }

    var body: some View {
        let tint = score.grade.color
        let axes = axes
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 26

            func point(_ index: Int, _ fraction: Double) -> CGPoint {
                let angle = -Double.pi / 2 + Double(index) * 2 * .pi / Double(axes.count)
                return CGPoint(
                    x: center.x + CGFloat(cos(angle) * fraction) * radius,
                    y: center.y + CGFloat(sin(angle) * fraction) * radius
                )
            }

            // The rings at 25, 50, 75 and 100.
            for ring in 1...4 {
                var polygon = Path()
                for index in axes.indices {
                    let corner = point(index, Double(ring) / 4)
                    index == 0 ? polygon.move(to: corner) : polygon.addLine(to: corner)
                }
                polygon.closeSubpath()
                context.stroke(polygon, with: .color(Color.rsStroke.opacity(ring == 4 ? 1 : 0.6)), lineWidth: 1)
            }

            // The spokes, and each part's name at its end.
            for (index, axis) in axes.enumerated() {
                var spoke = Path()
                spoke.move(to: center)
                spoke.addLine(to: point(index, 1))
                context.stroke(spoke, with: .color(Color.rsStroke.opacity(0.6)), lineWidth: 1)

                let label = Text(axis.label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.rsTextTertiary)
                context.draw(label, at: point(index, 1.22), anchor: .center)
            }

            // The attempt.
            var shape = Path()
            for (index, axis) in axes.enumerated() {
                let corner = point(index, max(0.04, axis.value / 100))
                index == 0 ? shape.move(to: corner) : shape.addLine(to: corner)
            }
            shape.closeSubpath()
            context.fill(shape, with: .color(tint.opacity(0.22)))
            context.stroke(shape, with: .color(tint), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

            for (index, axis) in axes.enumerated() {
                let corner = point(index, max(0.04, axis.value / 100))
                context.fill(Path(ellipseIn: CGRect(x: corner.x - 2.5, y: corner.y - 2.5, width: 5, height: 5)), with: .color(tint))
            }
        }
        .frame(height: 190)
        .accessibilityElement()
        .accessibilityLabel(axes.map { "\($0.label) \(Int($0.value.rounded()))" }.joined(separator: ", "))
    }
}
