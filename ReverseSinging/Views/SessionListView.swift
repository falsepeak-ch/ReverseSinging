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
            Image("cassette")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .opacity(0.6)
                .scaleIn(delay: 0.1)

            Text("No Saved Sessions")
                .font(.rsHeadingMedium)
                .foregroundColor(.rsText)
                .fadeIn(delay: 0.2)

            Text("Complete a reverse singing session and save it to see it here.")
                .font(.rsBodyMedium)
                .foregroundColor(.rsSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fadeIn(delay: 0.3)
        }
    }

    // MARK: - Session List

    private var sessionListView: some View {
        List {
            ForEach(Array(viewModel.appState.savedSessions.enumerated()), id: \.element.id) { index, session in
                SessionRow(session: session, viewModel: viewModel)
                    .listRowBackground(Color.rsSecondaryBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .slideIn(delay: Double(index) * 0.1)
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

                Button(action: {
                    withAnimation(.rsSpring) {
                        isExpanded.toggle()
                    }
                    HapticManager.shared.light()
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.rsBodyMedium)
                        .foregroundColor(.rsGold)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }

            // Recording badges
            HStack(spacing: 8) {
                if session.originalRecording != nil {
                    recordingBadge("Original", color: .rsGold)
                        .transition(.scale.combined(with: .opacity))
                }
                if session.reversedRecording != nil {
                    recordingBadge("Reversed", color: .rsGold.opacity(0.8))
                        .transition(.scale.combined(with: .opacity))
                }
                if session.attemptRecording != nil {
                    recordingBadge("Attempt", color: .rsGold.opacity(0.6))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.rsSpring, value: isExpanded)

            // Expanded details
            if isExpanded {
                Divider()
                    .transition(.opacity)

                VStack(spacing: 12) {
                    ForEach(Array(session.recordings.enumerated()), id: \.element.id) { index, recording in
                        RecordingRowButton(recording: recording, viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.rsSpring.delay(Double(index) * 0.05), value: isExpanded)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.rsTertiaryBackground)
                .cardShadow(.subtle)
        )
        .animation(.rsSpring, value: isExpanded)
    }

    private func recordingBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.rsCaption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Recording Row Button

struct RecordingRowButton: View {
    let recording: Recording
    @ObservedObject var viewModel: AudioViewModel
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            viewModel.playRecording(recording)
            HapticManager.shared.light()
        }) {
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
                        .foregroundColor(.rsGold)
                        .scaleEffect(1.1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.rsSecondaryBackground)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.rsQuick) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.rsQuick) {
                        isPressed = false
                    }
                }
        )
        .animation(.rsSpring, value: viewModel.appState.recordingState)
    }

    private func iconForType(_ type: Recording.RecordingType) -> String {
        switch type {
        case .original: return "mic.fill"
        case .reversed: return "arrow.triangle.2.circlepath"
        case .attempt: return "person.wave.2.fill"
        case .reversedAttempt: return "waveform.circle.fill"
        case .imported: return "square.and.arrow.down"
        }
    }

    private func colorForType(_ type: Recording.RecordingType) -> Color {
        switch type {
        case .original: return .rsGold
        case .reversed: return .rsGold.opacity(0.8)
        case .attempt: return .rsGold.opacity(0.7)
        case .reversedAttempt: return .rsGold.opacity(0.65)
        case .imported: return .rsGold.opacity(0.6)
        }
    }
}

// MARK: - Preview

#Preview {
    SessionListView(viewModel: AudioViewModel())
}
