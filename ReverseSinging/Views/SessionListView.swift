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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rsBackgroundAdaptive(for: colorScheme).ignoresSafeArea()

                if viewModel.appState.savedSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle(viewModel.appState.savedSessions.isEmpty ? "" : "Saved Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.rsHeadingSmall)
                            .foregroundStyle(Color.rsTurquoise)
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
                .frame(width: 140, height: 140)
                .scaleIn(delay: 0.1)

            Text("No Saved Sessions")
                .font(.custom("Eugello", size: 32))
                .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                .fadeIn(delay: 0.2)

            Text("Complete a reverse singing session and save it to see it here.")
                .font(.rsBodyMedium)
                .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fadeIn(delay: 0.3)
            Spacer()
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
        .background(Color.rsBackgroundAdaptive(for: colorScheme))
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.rsHeadingSmall)
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                    Text(session.formattedDate)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
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
                    recordingBadge("Original", color: .rsTurquoise)
                }
                if session.reversedRecording != nil {
                    recordingBadge("Reversed", color: .rsTurquoise.opacity(0.8))
                }
                if session.attemptRecording != nil {
                    recordingBadge("Attempt", color: .rsTurquoise.opacity(0.6))
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.rsSecondaryBackgroundAdaptive(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
        switch title {
        case "Original":
            return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Reversed":
            return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Attempt":
            return LinearGradient(colors: [Color.rsRed, Color.rsRed], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Recording Row Button

struct RecordingRowButton: View {
    let recording: Recording
    @ObservedObject var viewModel: AudioViewModel
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

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
                        .foregroundColor(Color.rsTextAdaptive(for: colorScheme))

                    Text(recording.formattedDuration)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                }

                Spacer()

                if case .playing = viewModel.appState.recordingState {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.rsBodyMedium)
                        .foregroundStyle(Color.rsTurquoise)
                        .scaleEffect(1.1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.rsTurquoise.opacity(0.2), lineWidth: 1)
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
        case .original: return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .reversed: return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .attempt: return LinearGradient(colors: [Color.rsRed, Color.rsRed], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .reversedAttempt: return LinearGradient(colors: [Color.rsTurquoise, Color.rsTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .imported: return LinearGradient(colors: [Color.rsRed, Color.rsRed], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Preview

#Preview {
    SessionListView(viewModel: AudioViewModel())
}
