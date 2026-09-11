//
//  RecordingIndicator.swift
//  ReverseSinging
//
//  Minimal, elegant recording indicator
//

import SwiftUI

struct RecordingIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.rsRecording)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .opacity(isPulsing ? 0.4 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }

            Text(Strings.Recording.indicator)
                .font(.rsCaption)
                .tracking(1.5)
                .foregroundColor(.rsRecording)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.rsRecording.opacity(0.08))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        RecordingIndicator()
    }
    .padding()
    .background(Color.rsBackground)
}
