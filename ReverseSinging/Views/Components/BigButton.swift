//
//  BigButton.swift
//  ReverseSinging
//
//  Large, tappable button with haptic feedback
//

import SwiftUI

struct BigButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false

    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                HapticManager.shared.medium()
                action()
            }
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.rsHeadingMedium)
                }

                Text(title)
                    .font(.rsButtonLarge)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isEnabled && !isLoading ? color : Color.rsButtonDisabled)
            )
            .shadow(color: color.opacity(isEnabled ? 0.3 : 0), radius: 12, x: 0, y: 4)
        }
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        BigButton(
            title: "Record",
            icon: "mic.fill",
            color: .red,
            action: {}
        )

        BigButton(
            title: "Reverse",
            icon: "arrow.triangle.2.circlepath",
            color: .purple,
            action: {},
            isEnabled: true,
            isLoading: true
        )

        BigButton(
            title: "Play",
            icon: "play.fill",
            color: .green,
            action: {},
            isEnabled: false
        )
    }
    .padding()
}
