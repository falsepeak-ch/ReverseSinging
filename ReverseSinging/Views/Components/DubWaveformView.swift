//
//  DubWaveformView.swift
//  ReverseSinging
//
//  The shape of a recording that already exists, with an optional second
//  take drawn over it for comparison
//
//  Takes pre-sampled values rather than a URL, so two clips can share a time axis.
//

import SwiftUI

/// A mirrored bar waveform with a playhead, and room for a second waveform on top.
///
/// The overlay is the point of this view: laying the user's take over the reference line is
/// what makes a timing difference visible — where they came in early, where they ran long.
///
/// Drawn in a `Canvas` rather than as a stack of shapes. During a take the overlay changes
/// twenty times a second, and several hundred `Capsule` views being re-laid-out at that rate
/// is what made the trace judder; a canvas is one draw pass with no layout at all.
struct DubWaveformView: View {
    /// The reference shape, drawn as the bed.
    let samples: [Float]
    /// The user's take, drawn over the bed. Nil before anything is recorded.
    var overlay: [Float]?
    var overlayTint: Color = .rsRecord
    /// Playhead position, 0...1. Nil when nothing is playing.
    var progress: Double?
    var height: CGFloat = 56
    var onTap: (() -> Void)?

    /// A floor so silence still reads as a rule rather than a gap.
    private let minimumBarHeight: CGFloat = 2

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            // Both waveforms are laid out on the reference's slot width. That is what shares
            // the time axis between them: a take that runs long keeps drawing at the same
            // seconds-per-bar and runs off the end of the rail, rather than being squeezed to
            // the same width and looking identical to a take that landed perfectly.
            let slot = size.width / CGFloat(max(samples.count, 1))
            let barWidth = max(1, slot - 1)
            let playhead = progress.map { CGFloat(min(max($0, 0), 1)) * size.width }

            for (index, value) in samples.enumerated() {
                let rect = barRect(index: index, value: value, slot: slot, width: barWidth, in: size)
                // Bars behind the playhead read as played, the way a scrubber fills.
                let isPlayed = playhead.map { rect.midX < $0 } ?? false
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(isPlayed ? .rsTextSecondary : .rsSurface3)
                )
            }

            if let overlay, !overlay.isEmpty {
                let tint = overlayTint.opacity(0.55)
                for (index, value) in overlay.enumerated() {
                    let rect = barRect(index: index, value: value, slot: slot, width: barWidth, in: size)
                    // The canvas clips anyway; stopping here saves drawing a take that ran to
                    // three times the length of the line.
                    guard rect.minX < size.width else { break }
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(tint)
                    )
                }
            }

            if let playhead {
                context.fill(
                    Path(CGRect(x: playhead - 0.75, y: 0, width: 1.5, height: size.height)),
                    with: .color(.rsTextPrimary)
                )
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private func barRect(
        index: Int,
        value: Float,
        slot: CGFloat,
        width: CGFloat,
        in size: CGSize
    ) -> CGRect {
        let barHeight = max(minimumBarHeight, CGFloat(value) * size.height)
        return CGRect(
            x: CGFloat(index) * slot + (slot - width) / 2,
            y: (size.height - barHeight) / 2,
            width: width,
            height: barHeight
        )
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()

        VStack(spacing: 24) {
            DubWaveformView(
                samples: (0..<96).map { _ in Float.random(in: 0.05...1) },
                progress: 0.4
            )

            DubWaveformView(
                samples: (0..<96).map { _ in Float.random(in: 0.05...1) },
                overlay: (0..<70).map { _ in Float.random(in: 0.05...0.9) },
                progress: nil
            )
        }
        .padding(EditorMetrics.gutter)
    }
}
