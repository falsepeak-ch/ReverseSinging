//
//  AnimatedCounter.swift
//  ReverseSinging
//
//  Smooth animated number counter
//

import SwiftUI

struct AnimatedCounter: View {
    let value: TimeInterval
    let font: Font
    let color: Color

    @State private var displayValue: TimeInterval = 0

    var body: some View {
        Text(displayValue.rsClock)
            .font(font)
            .foregroundColor(color)
            .monospaced()
            .contentTransition(.numericText(value: displayValue))
            .animation(.smooth(duration: 0.3), value: displayValue)
            .onChange(of: value) { _, newValue in
                withAnimation(.smooth(duration: 0.3)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        AnimatedCounter(
            value: 125.0,
            font: .rsTimerLarge,
            color: .rsTextOnTurquoise
        )
        .padding()
        .background(Color.rsTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    .padding()
}
