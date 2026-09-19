//
//  ProcessingIndicator.swift
//  ReverseSinging
//
//  Elegant processing/loading indicator
//

import SwiftUI

struct ProcessingIndicator: View {
    let message: String
    /// 0...1 when the work can be measured. Nil keeps the indeterminate spinner.
    ///
    /// Worth passing wherever the wait can run past a few seconds: converting a pack's
    /// scene video takes a minute or more, and a spinner with no numbers on it is
    /// indistinguishable from a hang.
    var progress: Double? = nil
    @State private var isAnimating = false
    @State private var opacity: Double = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.rsStrokeStrong, lineWidth: 1)
                        .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }

                // Center icon
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.rsTextSecondary)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 2.0)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .frame(height: 100)

            Text(message)
                .editorLabelStyle(.rsTextSecondary)
                .opacity(opacity)

            if let progress {
                // Deliberately not gated on the fade-in `opacity`: the bar is the part that
                // proves the app is still working, so it must not depend on an appearance
                // animation having run.
                progressBar(progress)
            }
        }
        .padding(36)
        .editorPanel(.rsSurface2)
        .cardShadow(.floating)
        .onAppear {
            isAnimating = true
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Determinate Bar

private extension ProcessingIndicator {

    /// A hairline track with a percentage. The same vocabulary as the transport chrome,
    /// so a long job reads as progress rather than as a stall.
    func progressBar(_ value: Double) -> some View {
        let clamped = min(max(value, 0), 1)

        return VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.rsSurface3)
                        .frame(height: 3)

                    Rectangle()
                        .fill(Color.rsTextPrimary)
                        .frame(width: geometry.size.width * clamped, height: 3)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(width: 180, height: 3)
            .animation(.easeOut(duration: 0.2), value: clamped)

            Text("\(Int(clamped * 100))%")
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextTertiary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: clamped)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        ProcessingIndicator(message: "Reversing audio...")

        ProcessingIndicator(message: "Converting scene video…", progress: 0.42)
    }
    .padding()
    .background(Color.rsBackground)
}
