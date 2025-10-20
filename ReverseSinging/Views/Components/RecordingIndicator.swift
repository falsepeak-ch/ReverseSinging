//
//  RecordingIndicator.swift
//  ReverseSinging
//
//  Pulsing recording indicator
//

import SwiftUI

struct RecordingIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.rsRecording)
                .frame(width: 12, height: 12)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.6 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }

            Text("Recording...")
                .font(.rsBodyMedium)
                .foregroundColor(.rsRecording)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.rsRecording.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    RecordingIndicator()
        .padding()
}
