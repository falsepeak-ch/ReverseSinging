//
//  SessionListView.swift
//  ReverseSinging
//
//  List of saved recording sessions
//

import SwiftUI

struct SessionListView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rsBackground.ignoresSafeArea()

                if viewModel.appState.savedSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("Saved Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.rsSecondaryText)

            Text("No Saved Sessions")
                .font(.rsHeadingMedium)
                .foregroundColor(.rsText)

            Text("Complete a reverse singing session and save it to see it here.")
                .font(.rsBodyMedium)
                .foregroundColor(.rsSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Session List

    private var sessionListView: some View {
        List {
            ForEach(viewModel.appState.savedSessions) { session in
                SessionRow(session: session, viewModel: viewModel)
                    .listRowBackground(Color.rsSecondaryBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = viewModel.appState.savedSessions[index]
            viewModel.deleteSession(session)
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: AudioSession
    @ObservedObject var viewModel: AudioViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.rsHeadingSmall)
                        .foregroundColor(.rsText)

                    Text(session.formattedDate)
                        .font(.rsCaption)
                        .foregroundColor(.rsSecondaryText)
                }

                Spacer()

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsPrimary)
                }
            }

            // Recording badges
            HStack(spacing: 8) {
                if session.originalRecording != nil {
                    recordingBadge("Original", color: .blue)
                }
                if session.reversedRecording != nil {
                    recordingBadge("Reversed", color: .purple)
                }
                if session.attemptRecording != nil {
                    recordingBadge("Attempt", color: .orange)
                }
            }

            // Expanded details
            if isExpanded {
                Divider()

                VStack(spacing: 12) {
                    ForEach(session.recordings) { recording in
                        RecordingRowButton(recording: recording, viewModel: viewModel)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.rsTertiaryBackground)
        )
    }

    private func recordingBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.rsCaption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.2))
            )
    }
}

// MARK: - Recording Row Button

struct RecordingRowButton: View {
    let recording: Recording
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        Button(action: { viewModel.playRecording(recording) }) {
            HStack {
                Image(systemName: iconForType(recording.type))
                    .font(.rsBodyLarge)
                    .foregroundColor(colorForType(recording.type))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.type.rawValue)
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsText)

                    Text(recording.formattedDuration)
                        .font(.rsCaption)
                        .foregroundColor(.rsSecondaryText)
                }

                Spacer()

                if case .playing = viewModel.appState.recordingState {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsPlaying)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.rsSecondaryBackground)
            )
        }
    }

    private func iconForType(_ type: Recording.RecordingType) -> String {
        switch type {
        case .original: return "mic.fill"
        case .reversed: return "arrow.triangle.2.circlepath"
        case .attempt: return "person.wave.2.fill"
        case .imported: return "square.and.arrow.down"
        }
    }

    private func colorForType(_ type: Recording.RecordingType) -> Color {
        switch type {
        case .original: return .blue
        case .reversed: return .purple
        case .attempt: return .orange
        case .imported: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    SessionListView(viewModel: AudioViewModel())
}
