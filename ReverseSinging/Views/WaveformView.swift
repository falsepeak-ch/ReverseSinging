//
//  WaveformView.swift
//  ReverseSinging
//
//  Dynamic audio waveform visualization
//

import SwiftUI

struct WaveformView: View {
    let level: Float // 0.0 to 1.0
    let barCount: Int
    let color: Color

    @State private var heights: [CGFloat] = []

    init(level: Float, barCount: Int = 50, color: Color = .rsWaveform) {
        self.level = level
        self.barCount = barCount
        self.color = color
        _heights = State(initialValue: Array(repeating: 0.1, count: barCount))
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(
                            width: (geometry.size.width / CGFloat(barCount)) - 2,
                            height: heights[index] * geometry.size.height
                        )
                        .animation(
                            .easeInOut(duration: 0.1)
                            .delay(Double(index) * 0.005),
                            value: heights[index]
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: level) { _, newValue in
                updateWaveform(level: newValue)
            }
        }
        .onAppear {
            updateWaveform(level: level)
        }
    }

    private func updateWaveform(level: Float) {
        let baseLevel = CGFloat(max(0.1, level))

        heights = (0..<barCount).map { index in
            let phase = Double(index) / Double(barCount)
            let randomVariation = CGFloat.random(in: 0.7...1.3)
            let waveEffect = sin(phase * .pi * 2) * 0.3 + 0.7

            return baseLevel * randomVariation * CGFloat(waveEffect)
        }
    }
}

// MARK: - Static Waveform

struct StaticWaveformView: View {
    let url: URL
    let color: Color
    let barCount: Int

    @State private var samples: [Float] = []

    init(url: URL, color: Color = .rsWaveform, barCount: Int = 100) {
        self.url = url
        self.color = color
        self.barCount = barCount
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(
                            width: (geometry.size.width / CGFloat(barCount)) - 1,
                            height: CGFloat(sample) * geometry.size.height
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadWaveform()
        }
    }

    private func loadWaveform() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let audioFile = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: audioFile.processingFormat,
                      frameCapacity: UInt32(audioFile.length)
                  ) else {
                return
            }

            try? audioFile.read(into: buffer)

            guard let floatData = buffer.floatChannelData?[0] else { return }

            let frameLength = Int(buffer.frameLength)
            let samplesPerBar = max(1, frameLength / barCount)

            var processedSamples: [Float] = []

            for i in 0..<barCount {
                let start = i * samplesPerBar
                let end = min(start + samplesPerBar, frameLength)

                var sum: Float = 0
                for j in start..<end {
                    sum += abs(floatData[j])
                }

                let average = sum / Float(end - start)
                processedSamples.append(min(1.0, max(0.1, average * 10)))
            }

            DispatchQueue.main.async {
                samples = processedSamples
            }
        }
    }
}

import AVFoundation

// MARK: - Preview

#Preview("Dynamic Waveform") {
    VStack(spacing: 40) {
        WaveformView(level: 0.3, barCount: 50, color: .blue)
            .frame(height: 80)

        WaveformView(level: 0.7, barCount: 50, color: .red)
            .frame(height: 80)

        WaveformView(level: 1.0, barCount: 50, color: .green)
            .frame(height: 80)
    }
    .padding()
}
