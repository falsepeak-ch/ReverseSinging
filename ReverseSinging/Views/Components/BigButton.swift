//
//  BigButton.swift
//  ReverseSinging
//
//  Voxxa-inspired gradient pill buttons
//

import SwiftUI

struct BigButton: View {
    let title: String
    let icon: String
    let color: Color  // Kept for compatibility, but ignored for primary style
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var style: ButtonStyle = .primary

    enum ButtonStyle {
        case primary    // Gradient background (Voxxa-style)
        case secondary  // Dark gray background
        case destructive // Red/pink background
    }

    @State private var isPressed = false

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
                        .font(.rsButtonLarge)
                        .fontWeight(.semibold)
                }

                Text(title)
                    .font(.rsButtonLarge)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundColor(textColor)
            .background(backgroundView)
            .clipShape(Capsule())  // Pill shape like Voxxa
            .shadow(color: shadowColor, radius: 15, x: 0, y: 8)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .contentShape(Rectangle())  // Makes entire button area tappable
        }
        .buttonStyle(PressButtonStyle(isPressed: $isPressed))
        .disabled(!isEnabled || isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if !isEnabled || isLoading {
            Color.rsButtonDisabled
        } else {
            switch style {
            case .primary:
                // Voxxa-style gradient
                LinearGradient.voxxaPrimary
            case .secondary:
                Color.rsSecondaryBackground
            case .destructive:
                Color.rsButtonDestructive
            }
        }
    }

    private var textColor: Color {
        if !isEnabled || isLoading {
            return .rsSecondaryText
        }

        switch style {
        case .primary:
            return .white  // Always white on gradients
        case .secondary:
            return .rsText
        case .destructive:
            return .white
        }
    }

    private var shadowColor: Color {
        guard isEnabled && !isPressed else {
            return Color.black.opacity(0.1)
        }

        switch style {
        case .primary:
            return Color.rsGradientPurple.opacity(0.4)
        case .secondary:
            return Color.black.opacity(0.2)
        case .destructive:
            return Color.rsError.opacity(0.4)
        }
    }
}

// MARK: - Compact Button

struct CompactButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var color: Color = .rsGradientCyan

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.rsButtonMedium)
                Text(title)
                    .font(.rsButtonMedium)
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .contentShape(Capsule())  // Makes entire button area tappable
        }
        .buttonStyle(PressButtonStyle(isPressed: $isPressed))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Press Button Style

struct PressButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        BigButton(
            title: "yes, let's record!",
            icon: "arrow.right",
            color: .rsGradientCyan,  // Ignored for primary
            action: {},
            style: .primary
        )

        BigButton(
            title: "continue",
            icon: "arrow.right",
            color: .rsGradientCyan,
            action: {},
            isLoading: true,
            style: .primary
        )

        BigButton(
            title: "Import Audio",
            icon: "square.and.arrow.down",
            color: .rsPlaying,
            action: {},
            style: .secondary
        )

        BigButton(
            title: "Delete Session",
            icon: "trash",
            color: .rsError,
            action: {},
            style: .destructive
        )

        HStack {
            CompactButton(title: "Speed", icon: "gauge", action: {})
            CompactButton(title: "Loop", icon: "repeat", action: {})
        }
    }
    .padding()
    .background(Color.rsBackground)
}
