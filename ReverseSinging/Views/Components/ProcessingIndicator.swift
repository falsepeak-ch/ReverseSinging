//
//  ProcessingIndicator.swift
//  ReverseSinging
//
//  Elegant processing/loading indicator
//

import SwiftUI

struct ProcessingIndicator: View {
    let message: String
    @State private var isAnimating = false
    @State private var opacity: Double = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.rsTurquoise.opacity(0.2), lineWidth: 2)
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
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.rsTurquoise)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 2.0)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .frame(height: 100)

            Text(message)
                .font(.rsBodyMedium)
                .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                .opacity(opacity)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.rsCardBackground(for: colorScheme))
                .cardShadow(.elevated)
        )
        .onAppear {
            isAnimating = true
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Compact Processing

struct CompactProcessingIndicator: View {
    @State private var isRotating = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.rsBodyMedium)
                .foregroundColor(.rsTurquoise)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: isRotating
                )
                .onAppear { isRotating = true }

            Text("Processing...")
                .font(.rsBodyMedium)
                .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.rsTurquoise.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        ProcessingIndicator(message: "Reversing audio...")

        CompactProcessingIndicator()
    }
    .padding()
    .background(Color.rsBackground)
}
