//
//  BigButton.swift
//  ReverseSinging
//
//  Icon-inspired solid color pill buttons
//

import SwiftUI

struct BigButton: View {
    @Environment(\.colorScheme) var colorScheme

    let title: String
    let icon: String
    let color: Color  // Kept for compatibility, but ignored for primary style
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var style: ButtonStyle = .primary
    var textFont: Font? = nil  // Optional custom font for text
    var iconFont: Font? = nil  // Optional custom font for icon

    enum ButtonStyle {
        case primary    // Turquoise solid background
        case secondary  // Charcoal/Cream background
        case destructive // Red solid background
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
                        .font(iconFont ?? .rsButtonLarge)
                        .fontWeight(.semibold)
                }

                Text(title)
                    .font(textFont ?? .rsButtonLarge)
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
                // Turquoise solid background
                Color.rsTurquoise
            case .secondary:
                // Charcoal in dark mode, cream in light mode
                Color.rsButtonSecondaryAdaptive(for: colorScheme)
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
            return .rsTextOnTurquoise  // White on turquoise
        case .secondary:
            // White in dark mode, charcoal in light mode
            return Color.rsTextAdaptive(for: colorScheme)
        case .destructive:
            return .rsTextOnRed  // White on red
        }
    }

    private var shadowColor: Color {
        guard isEnabled && !isPressed else {
            return Color.black.opacity(0.1)
        }

        switch style {
        case .primary:
            // Turquoise glow in both modes
            return colorScheme == .dark
                ? Color.rsTurquoise.opacity(0.5)  // Bright turquoise glow in dark mode
                : Color.rsTurquoise.opacity(0.3)  // Subtle turquoise shadow in light mode
        case .secondary:
            return Color.black.opacity(0.2)
        case .destructive:
            return Color.rsRed.opacity(0.4)
        }
    }
}

// MARK: - Compact Button

struct CompactButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var color: Color = .rsTurquoise

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
            color: .rsTurquoise,  // Ignored for primary
            action: {},
            style: .primary
        )

        BigButton(
            title: "continue",
            icon: "arrow.right",
            color: .rsTurquoise,
            action: {},
            isLoading: true,
            style: .primary
        )

        BigButton(
            title: "Import Audio",
            icon: "square.and.arrow.down",
            color: .rsTurquoise,
            action: {},
            style: .secondary
        )

        BigButton(
            title: "Delete Session",
            icon: "trash",
            color: .rsRed,
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
