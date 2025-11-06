//
//  SimpleRecordingIndicator.swift
//  ReverseSinging
//
//  Simple recording indicator with three pulsing bars
//

import SwiftUI

struct SimpleRecordingIndicator: View {
    let state: RecordingState
    let isPlayingReversed: Bool  // To distinguish between playing original vs reversed

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(barColor)
                    .frame(width: 40, height: 6)
                    .opacity(shouldAnimate ? (isAnimating ? 1.0 : 0.3) : 0.3)
                    .animation(
                        shouldAnimate
                            ? Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15)
                            : .default,
                        value: isAnimating
                    )
            }
        }
        .onChange(of: state) { _, _ in
            updateAnimation()
        }
        .onAppear {
            updateAnimation()
        }
    }

    private var shouldAnimate: Bool {
        switch state {
        case .recording, .playing:
            return true
        case .idle, .reversing, .error:
            return false
        }
    }

    private var barColor: Color {
        switch state {
        case .recording:
            return .rsRecording  // Red
        case .playing:
            if isPlayingReversed {
                return .rsTurquoise  // Blue for reversed
            } else {
                return .rsSuccess  // Green for original/attempt
            }
        case .idle, .reversing, .error:
            return Color.rsSecondaryTextAdaptive(for: .dark)
        }
    }

    private func updateAnimation() {
        if shouldAnimate {
            isAnimating = true
        } else {
            isAnimating = false
        }
    }
}

#Preview("Idle") {
    VStack(spacing: 40) {
        SimpleRecordingIndicator(state: .idle, isPlayingReversed: false)
            .padding()
            .background(Color.rsBackgroundAdaptive(for: .dark))
    }
}

#Preview("Recording") {
    VStack(spacing: 40) {
        SimpleRecordingIndicator(state: .recording, isPlayingReversed: false)
            .padding()
            .background(Color.rsBackgroundAdaptive(for: .dark))
    }
}

#Preview("Playing Original") {
    VStack(spacing: 40) {
        SimpleRecordingIndicator(state: .playing, isPlayingReversed: false)
            .padding()
            .background(Color.rsBackgroundAdaptive(for: .dark))
    }
}

#Preview("Playing Reversed") {
    VStack(spacing: 40) {
        SimpleRecordingIndicator(state: .playing, isPlayingReversed: true)
            .padding()
            .background(Color.rsBackgroundAdaptive(for: .dark))
    }
}
