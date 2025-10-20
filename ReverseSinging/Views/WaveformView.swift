//
//  WaveformView.swift
//  ReverseSinging
//
//  Premium stylized waveform visualization
//

import SwiftUI
import Combine

struct WaveformView: View {
    let level: Float // 0.0 to 1.0
    let barCount: Int
    let color: Color
    let style: WaveformStyle

    @State private var heights: [CGFloat] = []
    @State private var isAnimating = false
    @State private var animationPhase: Double = 0

    // Timer for continuous animation
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    enum WaveformStyle {
        case recording  // Red, reactive bars
        case playing    // Blue, flowing bars
        case idle       // Gray, subtle bars
    }

    init(level: Float, barCount: Int = 80, color: Color? = nil, style: WaveformStyle = .idle) {
        self.level = level
        self.barCount = barCount
        self.style = style

        // Auto-select color based on style if not provided
        self.color = color ?? {
            switch style {
            case .recording: return .rsWaveformRecording
            case .playing: return .rsWaveformPlaying
            case .idle: return .rsWaveformInactive
            }
        }()

        _heights = State(initialValue: Array(repeating: 0.1, count: barCount))
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 1) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(barColor(for: index, geometry: geometry))
                        .frame(
                            width: barWidth(for: geometry),
                            height: heights[index] * geometry.size.height
                        )
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.7)
                            .delay(animationDelay(for: index)),
                            value: heights[index]
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: level) { _, newValue in
                updateWaveform(level: newValue)
            }
            .onReceive(timer) { _ in
                // Continuously update animation phase for flowing effect
                animationPhase += 0.1
                if isAnimating {
                    updateWaveform(level: level)
                }
            }
        }
        .onAppear {
            isAnimating = true
            updateWaveform(level: level)
        }
    }

    // MARK: - Styling

    private func barWidth(for geometry: GeometryProxy) -> CGFloat {
        max(2, (geometry.size.width / CGFloat(barCount)) - 1)
    }

    private func barColor(for index: Int, geometry: GeometryProxy) -> Color {
        // Create gradient effect across the waveform
        let normalizedIndex = CGFloat(index) / CGFloat(barCount)
        let opacity = 0.3 + (heights[index] * 0.7) // More visible when taller

        switch style {
        case .recording:
            return color.opacity(opacity)
        case .playing:
            // Gradient from blue to lighter blue
            return color.opacity(0.4 + (1.0 - normalizedIndex) * 0.6)
        case .idle:
            return color.opacity(0.4)
        }
    }

    private func animationDelay(for index: Int) -> Double {
        // Stagger animation from center outward - 10x more visible
        let center = Double(barCount) / 2.0
        let distanceFromCenter = abs(Double(index) - center)
        return distanceFromCenter * 0.02
    }

    // MARK: - Waveform Update

    private func updateWaveform(level: Float) {
        heights = (0..<barCount).map { index in
            flowingHeight(for: index, level: level)
        }
    }

    private func flowingHeight(for index: Int, level: Float) -> CGFloat {
        let normalizedIndex = Double(index) / Double(barCount)
        let baseLevel = CGFloat(max(0.15, min(1.0, level)))

        switch style {
        case .recording:
            // Highly reactive to actual audio input with slight per-bar variation
            let barVariation = sin((normalizedIndex * .pi * 8) + (animationPhase * 0.5)) * 0.2
            let audioReactiveHeight = baseLevel * (1.0 + barVariation)
            return CGFloat(max(0.1, audioReactiveHeight))

        case .playing:
            // Smooth flowing left-to-right wave - music equalizer feel
            let flow = sin((normalizedIndex * .pi * 3) + animationPhase)
            let flow2 = cos((normalizedIndex * .pi * 5) + (animationPhase * 0.7))
            let combinedFlow = (flow * 0.7 + flow2 * 0.3) * 0.5 + 0.5
            return baseLevel * CGFloat(combinedFlow) * 0.9

        case .idle:
            // Gentle breathing effect - calm and subtle
            let breathe = 1.0 + sin(animationPhase * 0.5) * 0.2
            let subtleWave = sin((normalizedIndex * .pi * 2) + (animationPhase * 0.3)) * 0.1
            return CGFloat(0.3 * breathe + subtleWave)
        }
    }
}

// MARK: - Static Waveform

struct StaticWaveformView: View {
    let url: URL
    let color: Color
    let barCount: Int

    @State private var samples: [Float] = []

    init(url: URL, color: Color = .rsWaveformActive, barCount: Int = 100) {
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
