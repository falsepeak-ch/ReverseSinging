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
    @Environment(\.colorScheme) var colorScheme
    @State private var showAudioControls = false

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

    // Audio control parameters
    @Binding var playbackSpeed: Double
    @Binding var isLooping: Bool
    @Binding var pitchShift: Float
    var onSpeedChange: ((Double) -> Void)?
    var onLoopToggle: (() -> Void)?
    var onPitchChange: ((Float) -> Void)?

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

                Text(deviceName ?? Strings.TimerCard.deviceMicrophone)
                    .font(.rsCaption)
                    .foregroundColor(textColor.opacity(0.7))

                Spacer()

                // Stop button (only when playing)
                if state == .playing, let stopAction = onStopPlayback {
                    Button(action: stopAction) {
                        Image(systemName: "stop.circle.fill")
                            .font(.rsHeadingSmall)
                            .foregroundColor(textColor.opacity(0.9))
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
                timeLabel(Strings.TimerCard.mins)
                    .frame(width: timeLabelWidth)
                Spacer()
                timeLabel(Strings.TimerCard.secs)
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

                // Section title
                Text(Strings.TimerCard.playAudio)
                    .font(.rsBodySmall)
                    .foregroundColor(textColor.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                VStack(spacing: 12) {
                    // Row 1: Original | Reversed
                    HStack(spacing: 12) {
                        playButton(
                            title: Strings.RecordingType.original,
                            icon: "play.circle.fill",
                            action: onPlayOriginal,
                            isEnabled: hasOriginal && state != .playing
                        )

                        playButton(
                            title: Strings.RecordingType.reversed,
                            icon: "play.circle.fill",
                            action: onPlayReversed,
                            isEnabled: hasReversed && state != .playing
                        )
                    }

                    // Row 2: Attempt | Reversed Attempt
                    HStack(spacing: 8) {
                        playButton(
                            title: Strings.RecordingType.attempt,
                            icon: "play.circle.fill",
                            action: onPlayAttempt,
                            isEnabled: hasAttempt && state != .playing
                        )

                        playButton(
                            title: Strings.RecordingType.reversedAttempt,
                            icon: "play.circle.fill",
                            action: onPlayReversedAttempt,
                            isEnabled: hasReversedAttempt && state != .playing,
                            isHighlighted: true
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }

            // Audio Controls Section (collapsible)
            if showPlaybackControls {
                Divider()
                    .background(textColor.opacity(0.2))
                    .padding(.horizontal, 20)

                // Audio Controls Header (always visible)
                Button(action: {
                    withAnimation(.rsBouncy) {
                        showAudioControls.toggle()
                    }
                    HapticManager.shared.light()
                }) {
                    HStack {
                        Text(Strings.TimerCard.audioControls)
                            .font(.rsBodySmall)
                            .foregroundColor(textColor.opacity(0.8))
                            .textCase(.uppercase)
                            .tracking(1.5)

                        Spacer()

                        Image(systemName: showAudioControls ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.rsBodyMedium)
                            .foregroundColor(textColor.opacity(0.8))
                            .rotationEffect(.degrees(showAudioControls ? 180 : 0))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Collapsible content
                if showAudioControls {
                    VStack(spacing: 16) {
                        // Loop Toggle
                        HStack {
                            Image(systemName: isLooping ? "repeat.1" : "repeat")
                                .font(.rsBodyMedium)
                                .foregroundColor(textColor.opacity(0.8))

                            Text(Strings.TimerCard.loop)
                                .font(.rsBodyMedium)
                                .foregroundColor(textColor)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { isLooping },
                                set: { _ in
                                    onLoopToggle?()
                                    HapticManager.shared.light()
                                }
                            ))
                            .tint(toggleColor)
                        }
                        .opacity(state == .recording ? 0.5 : 1.0)
                        .disabled(state == .recording)

                        // Playback Speed Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "speedometer")
                                    .font(.rsBodyMedium)
                                    .foregroundColor(textColor.opacity(0.8))

                                Text(Strings.TimerCard.speed)
                                    .font(.rsBodyMedium)
                                    .foregroundColor(textColor)

                                Spacer()

                                Text(String(format: "%.1fx", playbackSpeed))
                                    .font(.rsBodySmall)
                                    .foregroundColor(textColor.opacity(0.7))
                                    .monospacedDigit()
                            }

                            Slider(
                                value: Binding(
                                    get: { playbackSpeed },
                                    set: { newValue in
                                        onSpeedChange?(newValue)
                                    }
                                ),
                                in: 0.5...2.0,
                                step: 0.1
                            )
                            .tint(controlColor)
                        }
                        .opacity(state == .recording ? 0.5 : 1.0)
                        .disabled(state == .recording)

                        // Pitch Shift Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "tuningfork")
                                    .font(.rsBodyMedium)
                                    .foregroundColor(textColor.opacity(0.8))

                                Text(Strings.TimerCard.pitch)
                                    .font(.rsBodyMedium)
                                    .foregroundColor(textColor)

                                Spacer()

                                let semitones = Int(round(pitchShift / 100.0))
                                Text(semitones > 0 ? "+\(semitones)" : "\(semitones)")
                                    .font(.rsBodySmall)
                                    .foregroundColor(textColor.opacity(0.7))
                                    .monospacedDigit()
                                Text(Strings.TimerCard.semitones)
                                    .font(.rsCaption)
                                    .foregroundColor(textColor.opacity(0.5))
                            }

                            Slider(
                                value: Binding(
                                    get: { pitchShift },
                                    set: { newValue in
                                        onPitchChange?(newValue)
                                    }
                                ),
                                in: -1200...1200,
                                step: 100
                            )
                            .tint(controlColor)
                        }
                        .opacity(state == .recording ? 0.5 : 1.0)
                        .disabled(state == .recording)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
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
    private func playButton(title: String, icon: String, action: (() -> Void)?, isEnabled: Bool, isHighlighted: Bool = false) -> some View {
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
                    .fill(buttonBackgroundColor(isEnabled: isEnabled, isHighlighted: isHighlighted))
            )
            .foregroundColor(buttonForegroundColor(isEnabled: isEnabled, isHighlighted: isHighlighted))
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }

    private func buttonBackgroundColor(isEnabled: Bool, isHighlighted: Bool) -> Color {
        if isHighlighted && isEnabled {
            // Gold background for highlighted button
            return .rsGold.opacity(0.3)
        } else if isEnabled {
            return textColor.opacity(0.2)
        } else {
            return textColor.opacity(0.1)
        }
    }

    private func buttonForegroundColor(isEnabled: Bool, isHighlighted: Bool) -> Color {
        if isHighlighted && isEnabled {
            // Darker gold for text when highlighted
            return .rsGold
        } else if isEnabled {
            return textColor
        } else {
            return textColor.opacity(0.4)
        }
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
            return Color.rsCardBackground(for: colorScheme)
        case .recording:
            return .rsRed  // Red for recording
        case .playing:
            return .rsTurquoise  // Turquoise for playing
        case .processing:
            return .rsTurquoise  // Turquoise for processing
        }
    }

    private var textColor: Color {
        switch state {
        case .idle:
            return Color.rsTextAdaptive(for: colorScheme)
        case .recording:
            return .rsTextOnRed  // White on red
        case .playing, .processing:
            return .rsTextOnTurquoise  // White on turquoise
        }
    }

    private var controlColor: Color {
        // Adaptive control colors for proper contrast
        switch state {
        case .idle:
            // Card background (light/dark) - turquoise provides good contrast
            return .rsTurquoise
        case .recording:
            // Red background - white for maximum contrast
            return Color.white
        case .playing, .processing:
            // Turquoise background - white for maximum contrast (can't use turquoise on turquoise!)
            return Color.white
        }
    }

    private var toggleColor: Color {
        // Toggle switch needs high contrast color when enabled
        switch state {
        case .idle:
            // Use turquoise - contrasts well with light/dark card
            return .rsTurquoise
        case .recording:
            // Red matches recording theme and contrasts with white text
            return .rsRed
        case .playing, .processing:
            // Red contrasts strongly with turquoise background
            return .rsRed
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
    @Environment(\.colorScheme) var colorScheme

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
            return Color.rsCardBackground(for: colorScheme)
        case .recording:
            return .rsRed
        case .playing:
            return .rsTurquoise
        case .processing:
            return .rsTurquoise
        }
    }

    private var textColor: Color {
        switch state {
        case .idle:
            return Color.rsTextAdaptive(for: colorScheme)
        case .recording:
            return .rsTextOnRed
        case .playing, .processing:
            return .rsTextOnTurquoise
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
    @Previewable @State var playbackSpeed = 1.0
    @Previewable @State var isLooping = false
    @Previewable @State var pitchShift: Float = 0.0

    VStack(spacing: 20) {
        TimerCard(
            duration: 168.5,
            deviceName: "iPhone Microphone",
            isRecording: true,
            state: .recording,
            playbackSpeed: $playbackSpeed,
            isLooping: $isLooping,
            pitchShift: $pitchShift
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
            onStopPlayback: { print("Stop playback") },
            playbackSpeed: $playbackSpeed,
            isLooping: $isLooping,
            pitchShift: $pitchShift,
            onSpeedChange: { speed in print("Speed: \(speed)") },
            onLoopToggle: { print("Loop toggled") },
            onPitchChange: { pitch in print("Pitch: \(pitch)") }
        )

        CompactTimerCard(duration: 30.0, state: .recording)
        CompactTimerCard(duration: 125.0, state: .playing)
    }
    .padding()
    .background(Color.rsBackground)
}
