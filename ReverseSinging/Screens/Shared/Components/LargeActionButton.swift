//
//  LargeActionButton.swift
//  ReverseSinging
//
//  The transport row the simple skin and the pack screen share
//

import SwiftUI

/// A transport row: a state bar, an icon well, a label pair and a live meter.
///
/// Replaces the previous full-bleed colour block. Colour survives only in the 3pt
/// leading bar and the meter, which is what keeps a screen of these near-monochrome
/// while still making the armed action unmistakable.
struct LargeActionButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let dotCount: Int          // > 0 shows the live level meter
    let color: Color
    let isEnabled: Bool
    let recordingLevel: Float
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var smoothedLevel: CGFloat = 0

    private var isActive: Bool { dotCount > 0 }

    var body: some View {
        Button(action: {
            if isEnabled {
                HapticManager.shared.impact(.medium)
                action()
            }
        }) {
            HStack(spacing: 0) {
                // State bar. The row's only permanent colour
                Rectangle()
                    .fill(isEnabled ? color : Color.rsStroke)
                    .frame(width: 3)

                HStack(spacing: 14) {
                    iconWell

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.rsButtonMedium)
                            .tracking(0.3)
                            .foregroundColor(.rsTextPrimary)
                            .lineLimit(1)

                        if let subtitle {
                            Text(subtitle)
                                .font(.rsMeta)
                                .foregroundColor(.rsTextTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    if isActive {
                        LevelMeter(level: smoothedLevel, tint: color)
                    } else if isEnabled {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.rsTextTertiary)
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .fill(isActive ? color.opacity(0.10) : Color.rsSurface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .strokeBorder(
                        isActive ? color.opacity(0.5) : Color.rsStroke,
                        lineWidth: EditorMetrics.hairline
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.18), value: isEnabled)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .onChange(of: recordingLevel) { _, level in
            // Momentum smoothing so the meter settles instead of flickering
            smoothedLevel = smoothedLevel * 0.7 + CGFloat(level) * 0.3
        }
    }

    private var iconWell: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(isActive ? color : .rsTextSecondary)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.rsSurface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
            )
    }
}

// MARK: - Level Meter

/// Four segments that fill from the bottom, like a channel strip. Reads as a meter
/// at a glance, unlike the pulsing dots it replaces.
struct LevelMeter: View {
    let level: CGFloat
    var tint: Color = .rsRecord
    var barCount: Int = 4

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                let threshold = CGFloat(index + 1) / CGFloat(barCount)
                let isLit = level >= threshold * 0.85

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(isLit ? tint : Color.rsSurface3)
                    .frame(width: 3, height: 8 + CGFloat(index) * 5)
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }
}
