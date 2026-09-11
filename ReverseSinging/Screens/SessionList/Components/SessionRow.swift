//
//  SessionRow.swift
//  ReverseSinging
//
//  One saved session in the archive, expandable to its recordings
//

import SwiftUI

struct SessionRow: View {
    let session: AudioSession
    @ObservedObject var viewModel: ReverseGameViewModel
    @State private var isExpanded = false
    @Environment(\.colorScheme) var systemColorScheme

    private var effectiveColorScheme: ColorScheme {
        switch viewModel.appState.themeMode {
        case .system: return systemColorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.rsHeadingSmall)
                        .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                    Text(session.formattedDate)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                }

                Spacer()

                Button(action: {
                    withAnimation(.rsBouncy) {
                        isExpanded.toggle()
                    }
                    HapticManager.shared.light()
                }) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.rsHeadingSmall)
                        .foregroundStyle(Color.rsTurquoise)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }

            // Recording badges
            HStack(spacing: 8) {
                if session.originalRecording != nil {
                    recordingBadge(Strings.RecordingType.original, color: .rsTurquoise)
                }
                if session.reversedRecording != nil {
                    recordingBadge(Strings.RecordingType.reversed, color: .rsTurquoise.opacity(0.8))
                }
                if session.attemptRecording != nil {
                    recordingBadge(Strings.RecordingType.attempt, color: .rsTurquoise.opacity(0.6))
                }
            }

            // Expanded details
            if isExpanded {
                Divider()
                    .transition(.opacity)

                VStack(spacing: 12) {
                    ForEach(session.recordings, id: \.id) { recording in
                        RecordingRowButton(recording: recording, viewModel: viewModel)
                    }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                        .stroke(Color.rsTurquoise.opacity(0.15), lineWidth: 1.5)
                )
                .cardShadow(.card)
        )
    }

    private func recordingBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.rsCaption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(gradientForBadge(title))
            )
            .cardShadow(.subtle)
    }

    private func gradientForBadge(_ title: String) -> LinearGradient {
        // Match localized strings
        if title == Strings.RecordingType.original {
            return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if title == Strings.RecordingType.reversed {
            return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if title == Strings.RecordingType.attempt {
            return LinearGradient(colors: [Color.rsRed, Color.rsRed], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
