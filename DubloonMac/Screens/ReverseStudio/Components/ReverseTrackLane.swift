//
//  ReverseTrackLane.swift
//  DubloonMac
//
//  One track of a reverse-singing session: its header, its waveform, and its play key
//

import SwiftUI

struct ReverseTrackLane: View {
    let lane: ReverseStudioViewModel.Lane
    let samples: [Float]
    let isPlaying: Bool
    let progress: Double?
    let placeholder: String
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            header
            content
        }
        .frame(height: 72)
        .background(isPlaying ? lane.tint.opacity(0.06) : Color.clear)
        .overlay(alignment: .bottom) { EditorRule() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(lane.recording == nil ? .rsTextTertiary : .rsTextPrimary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isPlaying ? lane.tint.opacity(0.35) : Color.rsSurface3))
            }
            .buttonStyle(ProPressStyle())
            .disabled(lane.recording == nil || !isEnabled)
            .help(lane.title)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: lane.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(lane.tint)
                    Text(lane.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.rsTextPrimary)
                        .lineLimit(1)
                }
                Text(lane.recording.map { $0.duration.proShortTime } ?? "—")
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(Color.rsSurface1)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.rsStroke).frame(width: 1) }
    }

    @ViewBuilder
    private var content: some View {
        if lane.recording != nil {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(lane.tint.opacity(0.14))
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isPlaying ? lane.tint : lane.tint.opacity(0.35), lineWidth: isPlaying ? 1.5 : 1)

                ProWaveform(samples: samples, tint: lane.tint, progress: progress)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { if isEnabled { onToggle() } }
        } else {
            HStack {
                Text(placeholder)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextTertiary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.rsStroke, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            )
        }
    }
}
