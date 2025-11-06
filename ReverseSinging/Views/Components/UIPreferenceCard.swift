//
//  UIPreferenceCard.swift
//  ReverseSinging
//
//  UI preference selection card for onboarding
//

import SwiftUI

struct UIPreferenceCard: View {
    let mode: UIMode
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Icon preview
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.rsCardBackground(for: colorScheme))
                        .frame(height: 140)

                    modePreview
                }

                // Title and description
                VStack(spacing: 4) {
                    Text(mode.displayName)
                        .font(.rsHeadingMedium)
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                    Text(mode.description)
                        .font(.rsBodySmall)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.rsCardBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                isSelected ? Color.rsTurquoise : Color.clear,
                                lineWidth: 3
                            )
                    )
            )
            .cardShadow(isSelected ? .elevated : .card)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.rsSpring, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var modePreview: some View {
        if mode == .simple {
            // Simple UI preview: three stacked bars
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonColor(for: index))
                        .frame(height: 36)
                }
            }
            .padding(.horizontal, 24)
        } else {
            // Complex UI preview: grid with waveform representation
            VStack(spacing: 8) {
                // Waveform bars
                HStack(spacing: 4) {
                    ForEach(0..<12, id: \.self) { _ in
                        Capsule()
                            .fill(Color.rsTurquoise.opacity(0.6))
                            .frame(width: 4, height: CGFloat.random(in: 8...32))
                    }
                }

                Spacer()
                    .frame(height: 8)

                // Control buttons
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.rsTurquoise.opacity(0.3))
                            .frame(height: 24)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    private func buttonColor(for index: Int) -> Color {
        switch index {
        case 0:
            return Color.rsRecording.opacity(0.8)  // Red
        case 1:
            return Color.rsSuccess.opacity(0.8)    // Green
        case 2:
            return Color.rsTurquoise.opacity(0.8)  // Blue
        default:
            return Color.gray
        }
    }
}

#Preview("Simple - Selected") {
    UIPreferenceCard(
        mode: .simple,
        isSelected: true,
        action: {}
    )
    .padding()
    .frame(width: 320)
    .background(Color.rsBackgroundAdaptive(for: .dark))
}

#Preview("Simple - Not Selected") {
    UIPreferenceCard(
        mode: .simple,
        isSelected: false,
        action: {}
    )
    .padding()
    .frame(width: 320)
    .background(Color.rsBackgroundAdaptive(for: .dark))
}

#Preview("Complex - Selected") {
    UIPreferenceCard(
        mode: .complex,
        isSelected: true,
        action: {}
    )
    .padding()
    .frame(width: 320)
    .background(Color.rsBackgroundAdaptive(for: .dark))
}

#Preview("Both") {
    HStack(spacing: 16) {
        UIPreferenceCard(
            mode: .simple,
            isSelected: true,
            action: {}
        )

        UIPreferenceCard(
            mode: .complex,
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .background(Color.rsBackgroundAdaptive(for: .dark))
}
