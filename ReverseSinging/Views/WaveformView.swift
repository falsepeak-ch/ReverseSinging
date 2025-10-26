//
//  WaveformView.swift
//  ReverseSinging
//
//  Premium stylized waveform visualization
//

import SwiftUI
import Combine

struct WaveformView: View {
    @Environment(\.colorScheme) var colorScheme

    let level: Float // 0.0 to 1.0
    let barCount: Int
    let color: Color
    let style: WaveformStyle
    let recordingDuration: TimeInterval? // Optional recording time to display

    @State private var heights: [CGFloat] = []
    @State private var isAnimating = false
    @State private var animationPhase: Double = 0
    @State private var smoothedLevel: Float = 0
    @State private var previousHeights: [CGFloat] = []

    // Timer for continuous animation (60fps for smoothness)
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    enum WaveformStyle {
        case recording  // Red, reactive bars
        case playing    // Blue, flowing bars
        case idle       // Gray, subtle bars
    }

    init(level: Float, barCount: Int = 80, color: Color? = nil, style: WaveformStyle = .idle, recordingDuration: TimeInterval? = nil) {
        self.level = level
        self.barCount = barCount
        self.style = style
        self.recordingDuration = recordingDuration

        // Auto-select color based on style if not provided
        self.color = color ?? {
            switch style {
            case .recording: return .rsWaveformRecording
            case .playing: return .rsWaveformPlaying
            case .idle: return .rsWaveformInactive
            }
        }()

        _heights = State(initialValue: Array(repeating: 0.1, count: barCount))
        _previousHeights = State(initialValue: Array(repeating: 0.1, count: barCount))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Waveform bars
                HStack(alignment: .center, spacing: 1) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(barColor(for: index, geometry: geometry))
                            .frame(
                                width: barWidth(for: geometry),
                                height: heights[index] * geometry.size.height
                            )
                            .animation(
                                .easeInOut(duration: 0.15)
                                .delay(animationDelay(for: index)),
                                value: heights[index]
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Recording time overlay (bottom-right)
                if let duration = recordingDuration, style == .recording {
                    Text(formattedRecordingTime(duration))
                        .font(.rsBodyMedium)
                        .monospaced()
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                        )
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                }
            }
            .onChange(of: level) { _, newValue in
                // Smooth level changes using exponential moving average
                let smoothingFactor: Float = 0.3
                smoothedLevel = (smoothedLevel * (1 - smoothingFactor)) + (newValue * smoothingFactor)
                updateWaveform(level: smoothedLevel)
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

        // Select adaptive color based on style and color scheme
        let baseColor: Color
        switch style {
        case .recording:
            baseColor = Color.rsWaveformRecordingAdaptive(for: colorScheme)
        case .playing:
            baseColor = Color.rsWaveformPlayingAdaptive(for: colorScheme)
        case .idle:
            baseColor = Color.rsWaveformIdleAdaptive(for: colorScheme)
        }

        // Apply dynamic opacity based on height and style
        let opacity: CGFloat
        switch style {
        case .recording:
            // 50%-100% opacity - more visible range
            opacity = 0.5 + (heights[index] * 0.5)
        case .playing:
            // 60%-100% opacity with gradient effect
            opacity = 0.6 + (1.0 - normalizedIndex) * 0.4
        case .idle:
            // Fixed 70% opacity - much more visible than before
            opacity = 0.7
        }

        return baseColor.opacity(opacity)
    }

    private func animationDelay(for index: Int) -> Double {
        // Subtle stagger from center outward for natural feel
        let center = Double(barCount) / 2.0
        let distanceFromCenter = abs(Double(index) - center)
        return distanceFromCenter * 0.003 // Much more subtle
    }

    // MARK: - Waveform Update

    private func updateWaveform(level: Float) {
        let newHeights = (0..<barCount).map { index in
            flowingHeight(for: index, level: level)
        }

        // Apply momentum - smooth transition from previous heights
        heights = zip(heights, newHeights).map { previous, new in
            let momentum: CGFloat = 0.6 // Higher = more inertia
            return previous * momentum + new * (1 - momentum)
        }

        previousHeights = heights
    }

    private func flowingHeight(for index: Int, level: Float) -> CGFloat {
        let normalizedIndex = Double(index) / Double(barCount)
        let baseLevel = CGFloat(max(0.15, min(1.0, level)))

        switch style {
        case .recording:
            // More natural audio-reactive pattern with subtle variation
            // Use smoother, slower-frequency waves for natural look
            let seed = Double(index) * 2.5 + animationPhase * 0.8
            let wave1 = sin(seed * 3.2) * 0.5  // Primary wave
            let wave2 = cos(seed * 2.1) * 0.3  // Secondary harmonic
            let variation = (wave1 + wave2) / 2.0  // Range: -0.4 to 0.4

            // Neighboring bar influence for cohesive movement
            let neighborInfluence = sin(normalizedIndex * .pi * 4 + animationPhase * 0.5) * 0.15

            // Combine: 75% audio level, 15% variation, 10% neighbor
            let combinedVariation = variation * 0.15 + neighborInfluence
            let variationFactor = 1.0 + combinedVariation
            let audioReactiveHeight = baseLevel * CGFloat(variationFactor)

            return CGFloat(max(0.12, min(0.95, audioReactiveHeight)))

        case .playing:
            // Smooth flowing wave with natural easing
            let flow = sin((normalizedIndex * .pi * 2.5) + animationPhase * 0.7)
            let flow2 = cos((normalizedIndex * .pi * 3.5) + (animationPhase * 0.5))
            let combinedFlow = (flow * 0.6 + flow2 * 0.4) * 0.5 + 0.5

            // Add gentle position-based variation
            let positionVariation = sin(normalizedIndex * .pi) * 0.1
            return baseLevel * CGFloat(combinedFlow + positionVariation) * 0.85

        case .idle:
            // Very subtle breathing effect - calm and minimal
            let breathe = 1.0 + sin(animationPhase * 0.4) * 0.15
            let subtleWave = sin((normalizedIndex * .pi * 1.5) + (animationPhase * 0.2)) * 0.08
            return CGFloat(0.25 * breathe + subtleWave)
        }
    }

    // MARK: - Recording Time Formatting

    private func formattedRecordingTime(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
