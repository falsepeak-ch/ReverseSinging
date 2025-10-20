//
//  StatusBadge.swift
//  ReverseSinging
//
//  Modern status badge chips
//

import SwiftUI

struct StatusBadge: View {
    let title: String
    let icon: String
    let color: Color
    let isActive: Bool

    init(title: String, icon: String, color: Color = .rsGold, isActive: Bool = false) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.rsCaption)
                .foregroundColor(foregroundColor)

            Text(title)
                .font(.rsCaption)
                .foregroundColor(foregroundColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(borderColor, lineWidth: isActive ? 1.5 : 0)
        )
        .cardShadow(isActive ? .subtle : .none)
    }

    private var backgroundColor: Color {
        if isActive {
            return color.opacity(0.15)
        } else {
            return Color.rsSecondaryBackground
        }
    }

    private var foregroundColor: Color {
        if isActive {
            return color
        } else {
            return .rsSecondaryText
        }
    }

    private var borderColor: Color {
        isActive ? color.opacity(0.3) : .clear
    }
}

// MARK: - Recording Status Badge

struct RecordingStatusBadge: View {
    let state: RecordingState
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            if case .recording = state {
                Circle()
                    .fill(Color.rsRecording)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0.5 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .onAppear { isPulsing = true }
            }

            Image(systemName: stateIcon)
                .font(.rsCaption)
                .foregroundColor(stateColor)

            Text(stateText)
                .font(.rsCaption)
                .foregroundColor(stateColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(stateColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var stateIcon: String {
        switch state {
        case .idle:
            return "waveform"
        case .recording:
            return "record.circle"
        case .playing:
            return "play.circle"
        case .reversing:
            return "arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.circle"
        }
    }

    private var stateText: String {
        switch state {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .playing:
            return "Playing"
        case .reversing:
            return "Processing"
        case .error(let message):
            return message
        }
    }

    private var stateColor: Color {
        switch state {
        case .idle:
            return .rsSecondaryText
        case .recording:
            return .rsRecording
        case .playing:
            return .rsPlaying
        case .reversing:
            return .rsProcessing
        case .error:
            return .rsError
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        StatusBadge(title: "Original", icon: "mic.fill", color: .blue, isActive: true)
        StatusBadge(title: "Reversed", icon: "arrow.triangle.2.circlepath", color: .purple, isActive: false)
        StatusBadge(title: "Attempt", icon: "person.wave.2.fill", color: .orange, isActive: true)

        Divider()

        RecordingStatusBadge(state: .idle)
        RecordingStatusBadge(state: .recording)
        RecordingStatusBadge(state: .playing)
        RecordingStatusBadge(state: .reversing)
    }
    .padding()
}
