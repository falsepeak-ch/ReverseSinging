//
//  BigButton.swift
//  ReverseSinging
//
//  Premium large button with refined styling
//

import SwiftUI

struct BigButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var style: ButtonStyle = .primary

    enum ButtonStyle {
        case primary    // Gold background
        case secondary  // Gray background
        case destructive // Red background
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
                        .tint(textColor)
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
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .cardShadow(isEnabled && !isPressed ? .card : .subtle)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .contentShape(Rectangle())  // Makes entire button area tappable
        }
        .buttonStyle(PressButtonStyle(isPressed: $isPressed))
        .disabled(!isEnabled || isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    private var backgroundColor: Color {
        guard isEnabled && !isLoading else {
            return Color.rsButtonDisabled
        }

        switch style {
        case .primary:
            return color
        case .secondary:
            return Color.rsButtonSecondary
        case .destructive:
            return Color.rsButtonDestructive
        }
    }

    private var textColor: Color {
        if !isEnabled || isLoading {
            return .rsSecondaryText
        }

        switch style {
        case .primary:
            // Check if color is gold/yellow for dark text
            if color == .rsGold || color == .rsButtonPrimary {
                return .rsTextOnGold
            }
            return .white
        case .secondary:
            return .rsText
        case .destructive:
            return .white
        }
    }
}

// MARK: - Compact Button

struct CompactButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var color: Color = .rsGold

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
            .background(color.opacity(0.1))
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
            title: "Record",
            icon: "mic.fill",
            color: .rsRecording,
            action: {},
            style: .primary
        )

        BigButton(
            title: "Reverse Audio",
            icon: "arrow.triangle.2.circlepath",
            color: .rsGold,
            action: {},
            isLoading: true,
            style: .primary
        )

        BigButton(
            title: "Import",
            icon: "square.and.arrow.down",
            color: .rsPlaying,
            action: {},
            style: .secondary
        )

        BigButton(
            title: "Delete",
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
