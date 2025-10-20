//
//  TimerCard.swift
//  ReverseSinging
//
//  Premium timer display card
//

import SwiftUI

struct TimerCard: View {
    let duration: TimeInterval
    let deviceName: String?
    let isRecording: Bool
    let state: TimerState

    enum TimerState {
        case idle
        case recording
        case playing
        case processing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section with device info
            HStack(spacing: 8) {
                Image(systemName: deviceIcon)
                    .font(.rsCaption)

                Text(deviceName ?? "Device Microphone (Default)")
                    .font(.rsCaption)
                    .foregroundColor(textColor.opacity(0.7))

                Spacer()

                if state != .idle {
                    batteryIndicator
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Timer display
            Text(formattedTime)
                .font(.rsTimerLarge)
                .foregroundColor(textColor)
                .monospacedDigit()
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .animation(.none, value: duration)

            // Time labels
            HStack(spacing: 0) {
                timeLabel("HOUR")
                    .frame(width: timeLabelWidth)
                Spacer()
                timeLabel("MINS")
                    .frame(width: timeLabelWidth)
                Spacer()
                timeLabel("SECS")
                    .frame(width: timeLabelWidth)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow(.elevated)
    }

    // MARK: - Computed Properties

    private var timeLabelWidth: CGFloat {
        UIScreen.main.bounds.width / 6
    }

    private var formattedTime: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var backgroundColor: Color {
        switch state {
        case .idle:
            return .rsCardBackground
        case .recording, .playing:
            return .rsGold
        case .processing:
            return .rsGoldLight
        }
    }

    private var textColor: Color {
        switch state {
        case .idle:
            return .rsText
        case .recording, .playing, .processing:
            return .rsTextOnGold
        }
    }

    private var deviceIcon: String {
        switch state {
        case .idle:
            return "waveform.circle"
        case .recording:
            return "mic.fill"
        case .playing:
            return "play.fill"
        case .processing:
            return "arrow.triangle.2.circlepath"
        }
    }

    private var batteryIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "battery.100")
                .font(.rsCaption)
            Text("58%")
                .font(.rsCaption)
        }
        .foregroundColor(textColor.opacity(0.7))
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.rsLabelSmall)
            .foregroundColor(textColor.opacity(0.5))
            .tracking(1)
    }
}

// MARK: - Compact Timer Card

struct CompactTimerCard: View {
    let duration: TimeInterval
    let state: TimerCard.TimerState

    var body: some View {
        HStack {
            Image(systemName: stateIcon)
                .font(.rsBodyMedium)
                .foregroundColor(textColor)

            Text(formattedTime)
                .font(.rsTimerSmall)
                .foregroundColor(textColor)
                .monospacedDigit()

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .cardShadow(.card)
    }

    private var formattedTime: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var backgroundColor: Color {
        switch state {
        case .idle:
            return .rsCardBackground
        case .recording, .playing:
            return .rsGold
        case .processing:
            return .rsGoldLight
        }
    }

    private var textColor: Color {
        switch state {
        case .idle:
            return .rsText
        case .recording, .playing, .processing:
            return .rsTextOnGold
        }
    }

    private var stateIcon: String {
        switch state {
        case .idle:
            return "waveform"
        case .recording:
            return "record.circle.fill"
        case .playing:
            return "play.circle.fill"
        case .processing:
            return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Preview

#Preview("Timer Card - Recording") {
    VStack(spacing: 20) {
        TimerCard(
            duration: 168.5,
            deviceName: "iPhone Microphone",
            isRecording: true,
            state: .recording
        )

        TimerCard(
            duration: 45.0,
            deviceName: nil,
            isRecording: false,
            state: .playing
        )

        CompactTimerCard(duration: 30.0, state: .recording)
        CompactTimerCard(duration: 125.0, state: .playing)
    }
    .padding()
    .background(Color.rsBackground)
}
