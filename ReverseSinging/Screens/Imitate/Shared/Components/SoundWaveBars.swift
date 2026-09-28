//
//  SoundWaveBars.swift
//  ReverseSinging
//
//  A clip's waveform as rounded bars, lit up to the playhead
//

import SwiftUI

/// The sound's shape at a glance: what to copy, and how far playback has got.
struct SoundWaveBars: View {
    let bars: [Float]
    /// 0...1, the part already played. Nil when nothing is playing.
    var progress: Double?
    var tint: Color = .rsHighlight

    var body: some View {
        Canvas { context, size in
            guard !bars.isEmpty else { return }
            let slot = size.width / CGFloat(bars.count)
            let width = max(2, slot * 0.55)
            for (index, value) in bars.enumerated() {
                let height = max(3, CGFloat(value) * size.height)
                let rect = CGRect(
                    x: CGFloat(index) * slot + (slot - width) / 2,
                    y: (size.height - height) / 2,
                    width: width, height: height
                )
                let isPlayed = progress.map { Double(index) / Double(bars.count) <= $0 } ?? false
                let color = progress == nil ? tint.opacity(0.75) : (isPlayed ? tint : Color.rsTextTertiary.opacity(0.5))
                context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
