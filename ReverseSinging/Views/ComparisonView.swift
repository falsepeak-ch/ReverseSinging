//
//  ComparisonView.swift
//  ReverseSinging
//
//  Comparison results screen showing similarity score and playback options
//

import SwiftUI

struct ComparisonView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let originalRecording: Recording
    let reversedAttempt: Recording
    let similarityScore: Double

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with score
                    scoreHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    // Waveform comparison
                    waveformComparison
                        .padding(.horizontal, 24)

                    // Playback buttons
                    playbackSection
                        .padding(.horizontal, 24)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.rsBackground.ignoresSafeArea())
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.accent)
                }
            }
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 16) {
            // Trophy/Star icon based on score
            Image(systemName: scoreIcon)
                .font(.system(size: 50))
                .foregroundColor(scoreColor)

            // Similarity percentage
            Text("\(Int(similarityScore))%")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.rsTurquoise)
                .monospacedDigit()

            // Score message
            Text(scoreMessage)
                .font(.rsBodyLarge)
                .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.rsCardBackground(for: colorScheme))
                .cardShadow(.card)
        )
    }

    // MARK: - Waveform Comparison

    private var waveformComparison: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Original waveform
                waveformColumn(
                    title: "Original",
                    recording: originalRecording
                )

                // Reversed attempt waveform
                waveformColumn(
                    title: "Your Try",
                    recording: reversedAttempt
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.rsCardBackground(for: colorScheme))
                .cardShadow(.card)
        )
    }

    private func waveformColumn(title: String, recording: Recording) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.rsCaption)
                .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))

            // Static waveform representation
            StaticWaveformView(url: recording.url)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(recording.formattedDuration)
                .font(.rsCaption)
                .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Play original
                BigButton(
                    title: "Play Original",
                    icon: "play.circle.fill",
                    color: .rsPlaying,
                    action: {
                        viewModel.playRecording(originalRecording)
                    },
                    style: .secondary
                )

                // Play reversed attempt
                BigButton(
                    title: "Play Your Try",
                    icon: "waveform.circle.fill",
                    color: .rsTurquoise,
                    action: {
                        viewModel.playRecording(reversedAttempt)
                    },
                    style: .secondary
                )
            }

            // Stop button if playing
            if case .playing = viewModel.appState.recordingState {
                CompactButton(
                    title: "Stop",
                    icon: "stop.fill",
                    action: { viewModel.stopPlayback() },
                    color: .rsError
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.rsCardBackground(for: colorScheme))
                .cardShadow(.card)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary: Save Session
            BigButton(
                title: "Save Session",
                icon: "checkmark.circle.fill",
                color: .rsSuccess,
                action: {
                    viewModel.saveSession()
                    dismiss()
                },
                style: .primary
            )

            // Secondary: Try Again
            BigButton(
                title: "Try Again",
                icon: "arrow.counterclockwise",
                color: .rsTurquoise,
                action: {
                    viewModel.reRecordAttempt()
                    dismiss()
                },
                style: .secondary
            )
        }
    }

    // MARK: - Computed Properties

    private var scoreIcon: String {
        if similarityScore >= 90 {
            return "trophy.fill"
        } else if similarityScore >= 70 {
            return "star.fill"
        } else if similarityScore >= 50 {
            return "hand.thumbsup.fill"
        } else {
            return "arrow.triangle.2.circlepath"
        }
    }

    private var scoreColor: Color {
        if similarityScore >= 90 {
            return .yellow
        } else if similarityScore >= 70 {
            return .rsTurquoise
        } else if similarityScore >= 50 {
            return .blue
        } else {
            return .rsSecondaryText
        }
    }

    private var scoreMessage: String {
        if similarityScore >= 90 {
            return "🌟 Amazing! Almost perfect!"
        } else if similarityScore >= 70 {
            return "🎉 Great job! Very close!"
        } else if similarityScore >= 50 {
            return "👍 Good attempt! Try again?"
        } else {
            return "💪 Keep practicing!"
        }
    }
}

// MARK: - Preview

#Preview {
    ComparisonView(
        viewModel: AudioViewModel(),
        originalRecording: Recording(
            url: URL(fileURLWithPath: "/tmp/original.m4a"),
            duration: 10.5,
            type: .original
        ),
        reversedAttempt: Recording(
            url: URL(fileURLWithPath: "/tmp/reversed.m4a"),
            duration: 10.3,
            type: .reversedAttempt
        ),
        similarityScore: 85.0
    )
}
