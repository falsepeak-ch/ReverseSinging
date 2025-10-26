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
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.rsBodyMedium.weight(.semibold))
                            .foregroundStyle(LinearGradient.voxxaPrimary)
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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .slideIn(delay: Double(index) * 0.1)
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.rsBackground)
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
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.rsHeadingSmall)
                        .foregroundStyle(LinearGradient.voxxaPrimary)
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.rsTertiaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(LinearGradient.voxxaPrimary.opacity(0.15), lineWidth: 1.5)
                )
                .cardShadow(.card)
        )
        .animation(.rsSpring, value: isExpanded)
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
        switch title {
        case "Original":
            return LinearGradient.voxxaMicrophone
        case "Reversed":
            return LinearGradient.voxxaIconCircle
        case "Attempt":
            return LinearGradient.voxxaRecording
        default:
            return LinearGradient.voxxaPrimary
        }
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
                    .foregroundStyle(gradientForType(recording.type))
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
                        .foregroundStyle(LinearGradient.voxxaPrimary)
                        .scaleEffect(1.1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.rsSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(LinearGradient.voxxaPrimary.opacity(0.2), lineWidth: 1)
                    )
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

    private func gradientForType(_ type: Recording.RecordingType) -> LinearGradient {
        switch type {
        case .original: return LinearGradient.voxxaMicrophone
        case .reversed: return LinearGradient.voxxaIconCircle
        case .attempt: return LinearGradient.voxxaRecording
        case .reversedAttempt: return LinearGradient.voxxaPrimary
        case .imported: return LinearGradient.voxxaSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    SessionListView(viewModel: AudioViewModel())
}
