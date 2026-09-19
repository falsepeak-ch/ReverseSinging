//
//  DubProgressBar.swift
//  ReverseSinging
//
//  Takes recorded against lines, as a filmstrip filling up
//

import SwiftUI

/// One tick per line, filled as takes land. At 62 lines this reads as a filmstrip
/// filling up, which is far more informative than a percentage bar.
struct DubProgressBar: View {
    let recorded: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                let ticks = min(total, 40)
                let spacing: CGFloat = 2
                let width = max(1, (geometry.size.width - spacing * CGFloat(ticks - 1)) / CGFloat(ticks))
                let filled = total > 0 ? Int((Double(recorded) / Double(total)) * Double(ticks)) : 0

                HStack(spacing: spacing) {
                    ForEach(0..<ticks, id: \.self) { index in
                        Rectangle()
                            .fill(index < filled ? Color.rsGood : Color.rsSurface3)
                            .frame(width: width, height: 4)
                    }
                }
            }
            .frame(height: 4)

            Text("\(recorded)/\(total)")
                .font(.rsTimecodeSmall)
                .foregroundColor(recorded == total && total > 0 ? .rsGood : .rsTextTertiary)
        }
    }
}
