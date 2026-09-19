//
//  RecordingRowButton.swift
//  ReverseSinging
//
//  One recording inside a saved session, played on tap
//

import SwiftUI

struct RecordingRowButton: View {
    let recording: Recording
    @ObservedObject var viewModel: ReverseGameViewModel
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
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .fill(Color.rsSecondaryBackgroundAdaptive(for: effectiveColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
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
