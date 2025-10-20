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

    let originalRecording: Recording
    let reversedAttempt: Recording
    let similarityScore: Double

    @State private var showingScore = false

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
                    .foregroundColor(.rsGold)
                }
            }
            .onAppear {
                withAnimation(.rsSpring.delay(0.3)) {
                    showingScore = true
                }
            }
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 16) {
            // Trophy/Star icon based on score
            Image(systemName: scoreIcon)
                .font(.system(size: 60))
                .foregroundColor(scoreColor)
                .scaleIn(delay: 0.1)

            // Similarity percentage
            Text("\(Int(similarityScore))%")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.rsGold)
                .monospacedDigit()
                .scaleEffect(showingScore ? 1.0 : 0.5)
                .opacity(showingScore ? 1.0 : 0.0)

            // Score message
            Text(scoreMessage)
                .font(.rsHeadingMedium)
                .foregroundColor(.rsText)
                .multilineTextAlignment(.center)
                .fadeIn(delay: 0.4)

            // Score bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.rsSecondaryBackground)
                        .frame(height: 12)

                    // Progress
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [scoreColor.opacity(0.8), scoreColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: showingScore ? geometry.size.width * CGFloat(similarityScore / 100.0) : 0,
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            .animation(.easeOut(duration: 1.0).delay(0.5), value: showingScore)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Waveform Comparison

    private var waveformComparison: some View {
        VStack(spacing: 16) {
            Text("Visual Comparison")
                .font(.rsBodyLarge)
                .foregroundColor(.rsText)
                .frame(maxWidth: .infinity, alignment: .leading)

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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.rsCardBackground)
                .cardShadow(.card)
        )
        .animatedCard(delay: 0.6)
    }

    private func waveformColumn(title: String, recording: Recording) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.rsCaption)
                .foregroundColor(.rsSecondaryText)

            // Static waveform representation
            StaticWaveformView(url: recording.url)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(recording.formattedDuration)
                .font(.rsCaption)
                .foregroundColor(.rsSecondaryText)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        VStack(spacing: 12) {
            Text("Listen & Compare")
                .font(.rsBodyLarge)
                .foregroundColor(.rsText)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                    color: .rsGold,
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
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.rsCardBackground)
                .cardShadow(.card)
        )
        .animation(.rsSpring, value: viewModel.appState.recordingState)
        .animatedCard(delay: 0.7)
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
                color: .rsGold,
                action: {
                    viewModel.reRecordAttempt()
                    dismiss()
                },
                style: .secondary
            )
        }
        .animatedCard(delay: 0.8)
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
            return .rsGold
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
