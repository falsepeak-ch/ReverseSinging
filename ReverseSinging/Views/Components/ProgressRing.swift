//
//  ProgressRing.swift
//  ReverseSinging
//
//  Circular progress indicator
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let color: Color

    init(progress: Double, lineWidth: CGFloat = 8, color: Color = .rsGold) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        ProgressRing(progress: 0.25, color: .red)
            .frame(width: 100, height: 100)

        ProgressRing(progress: 0.5, color: .blue)
            .frame(width: 100, height: 100)

        ProgressRing(progress: 0.75, color: .green)
            .frame(width: 100, height: 100)
    }
    .padding()
}
