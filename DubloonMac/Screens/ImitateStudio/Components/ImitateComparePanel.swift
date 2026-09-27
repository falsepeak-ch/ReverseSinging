//
//  ImitateComparePanel.swift
//  DubloonMac
//
//  The sound and the attempt at it, drawn one above the other on the same clock
//

import AVFoundation
import DubAudio
import DubScoring
import SwiftUI

/// Two tracks on one ruler, the way an audio editor lines up an original and a copy: the
/// sound to imitate on top, the attempt underneath. The attempt draws itself live while the
/// mic is open, then is replaced by its real waveform once it has been judged, so where it ran
/// long, came in late or missed a burst can be seen as well as heard.
struct ImitateComparePanel: View {
    @ObservedObject var challenge: ImitationChallengeViewModel

    @State private var referenceSamples: [Float] = []
    @State private var takeSamples: [Float] = []
    @State private var takeDuration: TimeInterval = 0
    /// The mic level, a sample every frame, while recording.
    @State private var liveLevels: [Float] = []

    private static let headerWidth: CGFloat = 112
    private static let liveInterval: TimeInterval = 1.0 / 30

    /// The ruler runs as long as an attempt is allowed to.
    private var span: TimeInterval { max(challenge.maximumTakeDuration, challenge.sound.duration, 0.5) }

    var body: some View {
        VStack(spacing: 0) {
            ProPanelHeader(title: MacStrings.Panel.compare, subtitle: span.proShortTime) {
                legend
            }

            VStack(spacing: 0) {
                ruler
                EditorRule()
                track(title: Strings.Dub.referenceTrack, icon: "waveform", tint: .proAudioClip, duration: challenge.sound.duration.proShortTime) {
                    referenceLane
                }
                EditorRule()
                track(title: Strings.Dub.yourTake, icon: "mic.fill", tint: .rsRecord, duration: takeReadout) {
                    takeLane
                }
                Spacer(minLength: 0)
            }
            .background(Color.rsSurface0)
        }
        .task(id: challenge.sound.id) {
            guard let url = challenge.sound.url else { return }
            referenceSamples = await WaveformSampler.shared.samples(from: url, buckets: 220)
        }
        .task(id: challenge.confettiSeed) { await loadTake() }
        .task(id: challenge.phase == .recording) { await traceLive() }
    }

    // MARK: - Header

    private var legend: some View {
        HStack(spacing: 10) {
            if let score = challenge.score, challenge.phase == .result {
                Text(verbatim: "\(Int(score.overall.rounded()))")
                    .font(.rsTimecodeSmall)
                    .foregroundColor(score.grade.color)
                Text(score.grade.badge)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(score.grade.color)
            }
        }
    }

    // MARK: - Ruler

    private var ruler: some View {
        HStack(spacing: 0) {
            Color.rsSurface1.frame(width: Self.headerWidth)
            Rectangle().fill(Color.rsStroke).frame(width: EditorMetrics.hairline)
            Canvas { context, size in
                let step = rulerStep
                var time: TimeInterval = 0
                while time <= span + 0.0001 {
                    let x = CGFloat(time / span) * size.width
                    let isMajor = abs((time / (step * 2)).rounded() - time / (step * 2)) < 0.001
                    let tick = CGRect(x: x, y: size.height - (isMajor ? 8 : 4), width: 1, height: isMajor ? 8 : 4)
                    context.fill(Path(tick), with: .color(Color.rsTextTertiary.opacity(isMajor ? 0.9 : 0.5)))
                    if isMajor && x < size.width - 24 {
                        let label = Text(String(format: "%.1fs", time))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.rsTextTertiary)
                        context.draw(label, at: CGPoint(x: x + 3, y: 2), anchor: .topLeading)
                    }
                    time += step
                }
            }
            .background(Color.rsSurface1)
        }
        .frame(height: 22)
    }

    /// Half a second between ticks for a short sound, a second for a long one.
    private var rulerStep: TimeInterval {
        span <= 3 ? 0.25 : span <= 8 ? 0.5 : 1
    }

    // MARK: - Tracks

    private func track<Lane: View>(
        title: String,
        icon: String,
        tint: Color,
        duration: String,
        @ViewBuilder lane: () -> Lane
    ) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.rsCaptionSmall)
                    .foregroundColor(.rsTextSecondary)
                    .labelStyle(TrackLabelStyle(tint: tint))
                    .lineLimit(1)
                Text(duration)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.rsTextTertiary)
            }
            .padding(.horizontal, 10)
            .frame(width: Self.headerWidth, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Color.rsSurface1)

            Rectangle().fill(Color.rsStroke).frame(width: EditorMetrics.hairline)

            lane()
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 54, maxHeight: 84)
    }

    private var referenceLane: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * CGFloat(challenge.sound.duration / span)
            clip(samples: referenceSamples, tint: .proAudioClip, width: width, height: geometry.size.height)
                .overlay(alignment: .leading) {
                    if challenge.playingClip == .reference {
                        Playhead(progress: { challenge.playbackProgress }, width: width)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { challenge.playReference() }
                .help(MacStrings.Menu.listen)
        }
    }

    @ViewBuilder
    private var takeLane: some View {
        GeometryReader { geometry in
            let size = geometry.size
            switch challenge.phase {
            case .recording, .countingIn:
                LiveTrace(levels: liveLevels, interval: Self.liveInterval, span: span)
                    .frame(width: size.width, height: size.height)
            default:
                if !takeSamples.isEmpty, challenge.phase == .result {
                    let width = size.width * CGFloat(min(1, takeDuration / span))
                    clip(samples: takeSamples, tint: .rsRecord, width: width, height: size.height)
                        .overlay(alignment: .leading) {
                            if challenge.playingClip == .take {
                                Playhead(progress: { challenge.playbackProgress }, width: width)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { challenge.playTake() }
                        .help(MacStrings.Menu.playTake)
                } else {
                    // Where the attempt will go: as long as the sound, outlined.
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.rsStroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: size.width * CGFloat(challenge.sound.duration / span), height: size.height)
                        .overlay {
                            if challenge.phase == .scoring {
                                ProgressView().controlSize(.small)
                            }
                        }
                }
            }
        }
    }

    /// A region on the track, the way an editor draws an audio clip: a tinted block holding
    /// its waveform, mirrored about the middle.
    private func clip(samples: [Float], tint: Color, width: CGFloat, height: CGFloat) -> some View {
        Envelope(samples: samples, tint: tint)
            .padding(.horizontal, 2)
            .frame(width: max(width, 8), height: height)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(tint.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(tint.opacity(0.55), lineWidth: 1))
    }

    private var takeReadout: String {
        switch challenge.phase {
        case .recording: challenge.recordingElapsed.proShortTime
        case .result where takeDuration > 0: takeDuration.proShortTime
        default: "—"
        }
    }

    // MARK: - Loading

    private func loadTake() async {
        guard let url = challenge.takeFileURL else {
            takeSamples = []
            takeDuration = 0
            return
        }
        takeDuration = Self.duration(of: url)
        let buckets = max(24, Int(220 * takeDuration / max(challenge.sound.duration, 0.1)))
        takeSamples = await WaveformSampler.shared.samples(from: url, buckets: min(buckets, 600))
    }

    private static func duration(of url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url), file.fileFormat.sampleRate > 0 else { return 0 }
        return Double(file.length) / file.fileFormat.sampleRate
    }

    /// Samples the mic's level while it is open, for the live trace.
    private func traceLive() async {
        guard challenge.phase == .recording else { return }
        liveLevels = []
        while !Task.isCancelled, challenge.phase == .recording {
            liveLevels.append(challenge.level)
            try? await Task.sleep(for: .seconds(Self.liveInterval))
        }
    }
}

// MARK: - Drawing

/// A waveform as a filled shape mirrored about its centre line, like a sample editor draws one.
private struct Envelope: View {
    let samples: [Float]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let mid = size.height / 2
            context.fill(Path(CGRect(x: 0, y: mid - 0.5, width: size.width, height: 1)), with: .color(tint.opacity(0.35)))
            guard samples.count > 1 else { return }
            let step = size.width / CGFloat(samples.count - 1)
            var shape = Path()
            shape.move(to: CGPoint(x: 0, y: mid))
            for (index, value) in samples.enumerated() {
                shape.addLine(to: CGPoint(x: CGFloat(index) * step, y: mid - CGFloat(value) * mid * 0.94))
            }
            for (index, value) in samples.enumerated().reversed() {
                shape.addLine(to: CGPoint(x: CGFloat(index) * step, y: mid + CGFloat(value) * mid * 0.94))
            }
            shape.closeSubpath()
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.95), tint.opacity(0.55), tint.opacity(0.95)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
    }
}

/// The attempt drawing itself as it is recorded, against the same clock as the ruler.
private struct LiveTrace: View {
    let levels: [Float]
    let interval: TimeInterval
    let span: TimeInterval

    var body: some View {
        Canvas { context, size in
            let mid = size.height / 2
            let slot = size.width * CGFloat(interval / span)
            var bars = Path()
            for (index, level) in levels.enumerated() {
                let height = max(1.5, CGFloat(min(1, level * 1.4)) * size.height * 0.94)
                bars.addRect(CGRect(x: CGFloat(index) * slot, y: mid - height / 2, width: max(1, slot - 0.5), height: height))
            }
            context.fill(bars, with: .color(.rsRecord.opacity(0.9)))
            let head = CGFloat(levels.count) * slot
            context.fill(Path(CGRect(x: head, y: 0, width: 1.5, height: size.height)), with: .color(.rsRecord))
        }
        .background(Color.rsRecord.opacity(0.06))
    }
}

/// The play position, redrawn every frame while a clip plays.
private struct Playhead: View {
    let progress: @MainActor () -> Double
    let width: CGFloat

    var body: some View {
        TimelineView(.animation) { _ in
            Rectangle()
                .fill(Color.white)
                .frame(width: 1.5)
                .shadow(color: .black.opacity(0.6), radius: 1)
                .offset(x: CGFloat(progress()) * width)
        }
        .frame(width: width, alignment: .leading)
        .allowsHitTesting(false)
    }
}

/// A track name with its colour swatch in front, as track headers carry.
private struct TrackLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5).fill(tint).frame(width: 3, height: 12)
            configuration.icon.font(.system(size: 10)).foregroundColor(tint)
            configuration.title
        }
    }
}
