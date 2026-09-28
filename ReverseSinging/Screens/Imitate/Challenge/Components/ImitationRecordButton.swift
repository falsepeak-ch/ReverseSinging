//
//  ImitationRecordButton.swift
//  ReverseSinging
//
//  The big red button: imitate, or stop early
//

import SwiftUI

/// Round, red, unmissable. A ring fills while recording, so the performer can see how long
/// they have left without reading a number.
struct ImitationRecordButton: View {
    let isRecording: Bool
    let isCountingIn: Bool
    /// 0...1 of the attempt's time used.
    let elapsed: Double
    let level: Float
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.rsSurface3, lineWidth: 4)

                if isRecording {
                    Circle()
                        .trim(from: 0, to: elapsed)
                        .stroke(Color.rsRecord, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: elapsed)
                }

                Circle()
                    .fill(Color.rsRecord.opacity(isEnabled ? 1 : 0.4))
                    .padding(8)
                    .scaleEffect(isRecording ? 0.9 + CGFloat(level) * 0.15 : 1)
                    .animation(.easeOut(duration: 0.08), value: level)

                Image(systemName: isRecording || isCountingIn ? "stop.fill" : "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 84, height: 84)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(isRecording ? Strings.Imitate.stop : Strings.Imitate.record)
    }
}
