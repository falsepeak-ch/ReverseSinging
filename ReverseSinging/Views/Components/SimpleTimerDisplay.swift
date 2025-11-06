//
//  SimpleTimerDisplay.swift
//  ReverseSinging
//
//  Simple timer display for recording/playback duration
//

import SwiftUI

struct SimpleTimerDisplay: View {
    let duration: TimeInterval
    let isVisible: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(formattedTime)
            .font(.rsTimerLarge)
            .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.rsSmooth, value: isVisible)
    }

    private var formattedTime: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview("Zero") {
    SimpleTimerDisplay(duration: 0, isVisible: true)
        .padding()
        .background(Color.rsBackgroundAdaptive(for: .dark))
}

#Preview("Recording") {
    SimpleTimerDisplay(duration: 45.3, isVisible: true)
        .padding()
        .background(Color.rsBackgroundAdaptive(for: .dark))
}

#Preview("Long Duration") {
    SimpleTimerDisplay(duration: 185.7, isVisible: true)
        .padding()
        .background(Color.rsBackgroundAdaptive(for: .dark))
}

#Preview("Hidden") {
    SimpleTimerDisplay(duration: 45.3, isVisible: false)
        .padding()
        .background(Color.rsBackgroundAdaptive(for: .dark))
}
