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

    // Play button callbacks and recordings
    var onPlayOriginal: (() -> Void)?
    var onPlayReversed: (() -> Void)?
    var onPlayAttempt: (() -> Void)?
    var onPlayReversedAttempt: (() -> Void)?
    var hasOriginal: Bool = false
    var hasReversed: Bool = false
    var hasAttempt: Bool = false
    var hasReversedAttempt: Bool = false
    var onStopPlayback: (() -> Void)?

    enum TimerState {
        case idle
        case recording
        case playing
        case processing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section with device info and stop button
            HStack(spacing: 8) {
                Image(systemName: deviceIcon)
                    .font(.rsCaption)

                Text(deviceName ?? "Device Microphone (Default)")
                    .font(.rsCaption)
                    .foregroundColor(textColor.opacity(0.7))

                Spacer()

                // Stop button (only when playing)
                if state == .playing, let stopAction = onStopPlayback {
                    Button(action: stopAction) {
                        Image(systemName: "stop.circle.fill")
                            .font(.rsHeadingSmall)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Timer display
            AnimatedCounter(
                value: duration,
                font: .rsTimerLarge,
                color: textColor
            )
            .padding(.vertical, 20)
            .padding(.horizontal, 20)

            // Time labels
            HStack(spacing: 0) {
                Spacer()
                timeLabel("MINS")
                    .frame(width: timeLabelWidth)
                Spacer()
                timeLabel("SECS")
                    .frame(width: timeLabelWidth)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, showPlaybackControls ? 12 : 16)

            // Play buttons grid (2x2)
            if showPlaybackControls {
                Divider()
                    .background(textColor.opacity(0.2))
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    // Row 1: Play Original | Play Reversed
                    HStack(spacing: 12) {
                        playButton(
                            title: "Play Original",
                            icon: "play.circle.fill",
                            action: onPlayOriginal,
                            isEnabled: hasOriginal && state != .playing
                        )

                        playButton(
                            title: "Play Reversed",
                            icon: "play.circle.fill",
                            action: onPlayReversed,
                            isEnabled: hasReversed && state != .playing
                        )
                    }

                    // Row 2: Play Attempt | Play Attempt Reversed
                    HStack(spacing: 12) {
                        playButton(
                            title: "Play Attempt",
                            icon: "play.circle.fill",
                            action: onPlayAttempt,
                            isEnabled: hasAttempt && state != .playing
                        )

                        playButton(
                            title: "Play Attempt Reversed",
                            icon: "play.circle.fill",
                            action: onPlayReversedAttempt,
                            isEnabled: hasReversedAttempt && state != .playing
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow(.elevated)
        .animation(.rsSpring, value: backgroundColor)
        .animation(.rsSpring, value: showPlaybackControls)
        .scaleIn(delay: 0.1)
    }

    // MARK: - Computed Properties

    private var showPlaybackControls: Bool {
        // Show when any recording exists
        hasOriginal || hasReversed || hasAttempt || hasReversedAttempt
    }

    @ViewBuilder
    private func playButton(title: String, icon: String, action: (() -> Void)?, isEnabled: Bool) -> some View {
        Button(action: {
            if let action = action {
                action()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.rsBodySmall)
                Text(title)
                    .font(.rsButtonSmall)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isEnabled ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            )
            .foregroundColor(isEnabled ? .white : .white.opacity(0.4))
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Computed Properties

    private var timeLabelWidth: CGFloat {
        UIScreen.main.bounds.width / 4  // For 2 labels (MINS, SECS)
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
        case .recording:
            return .rsGradientPink  // Pink for recording
        case .playing:
            return .rsGradientPurple  // Purple for playing
        case .processing:
            return .rsGradientBlue  // Blue for processing
        }
    }

    private var textColor: Color {
        switch state {
        case .idle:
            return .rsText
        case .recording, .playing, .processing:
            return .white  // Always white on gradient backgrounds
        }
    }

    private var controlColor: Color {
        // Controls use cyan/purple gradient colors
        switch state {
        case .playing:
            return .rsGradientCyan
        default:
            return .rsGradientPurple
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

            CompactAnimatedCounter(
                value: duration,
                font: .rsTimerSmall,
                color: textColor
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .cardShadow(.card)
        .animation(.rsSpring, value: backgroundColor)
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
        case .recording:
            return .rsGradientPink
        case .playing:
            return .rsGradientPurple
        case .processing:
            return .rsGradientBlue
        }
    }

    private var textColor: Color {
        switch state {
        case .idle:
            return .rsText
        case .recording, .playing, .processing:
            return .white
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
            state: .playing,
            onPlayOriginal: { print("Play original") },
            onPlayReversed: { print("Play reversed") },
            onPlayAttempt: { print("Play attempt") },
            onPlayReversedAttempt: { print("Play reversed attempt") },
            hasOriginal: true,
            hasReversed: true,
            hasAttempt: true,
            hasReversedAttempt: true,
            onStopPlayback: { print("Stop playback") }
        )

        CompactTimerCard(duration: 30.0, state: .recording)
        CompactTimerCard(duration: 125.0, state: .playing)
    }
    .padding()
    .background(Color.rsBackground)
}
