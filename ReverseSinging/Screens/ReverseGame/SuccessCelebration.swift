//
//  SuccessCelebration.swift
//  ReverseSinging
//
//  Success celebration animation
//

import SwiftUI

struct SuccessCelebration: View {
    @State private var scale: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var particlesOpacity: Double = 0
    @State private var rotation: Double = -45

    var body: some View {
        ZStack {
            // Particles
            ForEach(0..<12) { index in
                Circle()
                    .fill(Color.rsTurquoise)
                    .frame(width: 8, height: 8)
                    .offset(particleOffset(for: index))
                    .opacity(particlesOpacity)
                    .scaleEffect(particlesOpacity)
            }

            // Success circle
            Circle()
                .fill(Color.rsTurquoise)
                .frame(width: 80, height: 80)
                .scaleEffect(scale)

            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.rsTextOnTurquoise)
                .scaleEffect(checkmarkScale)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
                checkmarkScale = 1.0
                rotation = 0
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                particlesOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                particlesOpacity = 0
            }

            // Haptic feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                HapticManager.shared.success()
            }
        }
    }

    private func particleOffset(for index: Int) -> CGSize {
        let angle = CGFloat(index) * (360.0 / 12.0)
        let radians = angle * .pi / 180
        let distance: CGFloat = particlesOpacity > 0.5 ? 60 : 40

        return CGSize(
            width: cos(radians) * distance,
            height: sin(radians) * distance
        )
    }
}

// MARK: - Success Toast

struct SuccessToast: View {
    let message: String
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    @State private var offset: CGFloat = 100
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.rsHeadingSmall)
                .foregroundColor(.rsSuccess)

            Text(message)
                .font(.rsBodyMedium)
                .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.rsCardBackground(for: colorScheme))
                .cardShadow(.elevated)
        )
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
                opacity = 1.0
            }

            // Auto dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    offset = -100
                    opacity = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPresented = false
                }
            }

            HapticManager.shared.success()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.rsBackground.ignoresSafeArea()

        VStack(spacing: 60) {
            SuccessCelebration()

            SuccessToast(message: "Session saved successfully!", isPresented: .constant(true))
                .padding()
        }
    }
}
