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
    @Environment(\.colorScheme) var systemColorScheme

    // Computed effective color scheme based on theme mode
    private var effectiveColorScheme: ColorScheme {
        switch viewModel.appState.themeMode {
        case .system:
            return systemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rsBackgroundAdaptive(for: effectiveColorScheme).ignoresSafeArea()

                if viewModel.appState.savedSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .id(viewModel.appState.themeMode)
            .navigationTitle(viewModel.appState.savedSessions.isEmpty ? "" : Strings.SessionList.title)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Track screen view and session count
                let sessionsCount = viewModel.appState.savedSessions.count
                AnalyticsManager.shared.trackSessionListViewed(sessionsCount: sessionsCount)
                AnalyticsManager.shared.trackScreenViewed(screenName: "SessionListView")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.rsTextAdaptive(for: effectiveColorScheme))
                    }
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch viewModel.appState.themeMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
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

            Text(Strings.SessionList.Empty.title)
                .font(.custom("Eugello", size: 32))
                .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))
                .fadeIn(delay: 0.2)

            Text(Strings.SessionList.Empty.message)
                .font(.rsBodyMedium)
                .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
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
        .background(Color.rsBackgroundAdaptive(for: effectiveColorScheme))
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
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

// MARK: - Recording Row Button

struct RecordingRowButton: View {
    let recording: Recording
    @ObservedObject var viewModel: AudioViewModel
    @State private var isPressed = false
    @Environment(\.colorScheme) var systemColorScheme

    private var effectiveColorScheme: ColorScheme {
        switch viewModel.appState.themeMode {
        case .system: return systemColorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

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
                    Text(recording.localizedType)
                        .font(.rsBodyMedium)
                        .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))

                    Text(recording.formattedDuration)
                        .font(.rsCaption)
                        .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
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
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
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
