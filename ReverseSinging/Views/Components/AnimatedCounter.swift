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
        Text(formattedTime)
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
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

    private var formattedTime: String {
        let hours = Int(displayValue) / 3600
        let minutes = (Int(displayValue) % 3600) / 60
        let seconds = Int(displayValue) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Compact Animated Counter

struct CompactAnimatedCounter: View {
    let value: TimeInterval
    let font: Font
    let color: Color

    @State private var displayValue: TimeInterval = 0

    var body: some View {
        Text(formattedTime)
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
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

    private var formattedTime: String {
        let minutes = Int(displayValue) / 60
        let seconds = Int(displayValue) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        AnimatedCounter(
            value: 125.0,
            font: .rsTimerLarge,
            color: .rsTextOnGold
        )
        .padding()
        .background(Color.rsGold)
        .clipShape(RoundedRectangle(cornerRadius: 20))

        CompactAnimatedCounter(
            value: 45.0,
            font: .rsTimerSmall,
            color: .rsText
        )
    }
    .padding()
}
