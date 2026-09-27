//
//  DubTimelinePanel.swift
//  DubloonMac
//
//  The scene laid out in time: a ruler, the original lines as clips, the user's takes under
//  them, the scene's soundtrack, and a playhead across all of it
//

import SwiftUI
import DubAudio
import DubScoring

struct DubTimelinePanel: View {
    @ObservedObject var viewModel: DubEditorViewModel
    /// The scene clock, observed for every tick of the playhead.
    @ObservedObject var player: DubPlayer

    @State private var soundtrack: [Float] = []
    @State private var isScrubbing = false

    private var pack: DubPack { viewModel.pack }
    private var session: DubSessionViewModel { viewModel.session }
    private var duration: TimeInterval { viewModel.timelineDuration }
    private var contentWidth: CGFloat { CGFloat(duration) * viewModel.zoom }

    var body: some View {
        VStack(spacing: 0) {
            ProPanelHeader(title: Strings.Dub.timeline, subtitle: duration.proTimecode) {
                HStack(spacing: 6) {
                    Button(action: viewModel.zoomOut) { Image(systemName: "minus.magnifyingglass") }
                        .keyboardShortcut("-", modifiers: .command)
                    Slider(value: $viewModel.zoom, in: DubEditorViewModel.zoomRange)
                        .frame(width: 110)
                        .controlSize(.mini)
                    Button(action: viewModel.zoomIn) { Image(systemName: "plus.magnifyingglass") }
                        .keyboardShortcut("=", modifiers: .command)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.rsTextSecondary)
            }

            HStack(alignment: .top, spacing: 0) {
                trackHeaders

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                ruler
                                sceneTrack
                                takesTrack
                                soundtrackTrack
                            }

                            playhead
                        }
                        .frame(width: max(contentWidth, 1), alignment: .leading)
                    }
                    .scrollIndicators(.visible)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .onChange(of: session.currentLineIndex) { _, _ in
                        guard !player.isPlaying, let line = session.currentLine else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(line.id, anchor: .center)
                        }
                    }
                }
            }
            .background(Color.rsSurface0)
        }
        .task(id: pack.backingTrackURL) {
            guard let url = pack.backingTrackURL else { return }
            soundtrack = await WaveformSampler.shared.samples(from: url, buckets: 600)
        }
    }

    // MARK: - Headers

    private var trackHeaders: some View {
        VStack(spacing: 0) {
            Color.rsSurface1
                .frame(height: ProMetrics.rulerHeight)
                .overlay(alignment: .bottom) { EditorRule() }
            header(MacStrings.Panel.scene, icon: "film", tint: .rsHighlight)
            header(MacStrings.Panel.takes, icon: "mic.fill", tint: .rsRecord)
            header(Strings.Dub.original, icon: "waveform", tint: .proAudioClip)
            Spacer(minLength: 0)
        }
        .frame(width: ProMetrics.trackHeaderWidth)
        .frame(maxHeight: .infinity)
        .background(Color.rsSurface1)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.rsStroke).frame(width: 1)
        }
    }

    private func header(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(tint)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.rsTextSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: ProMetrics.trackHeight)
        .overlay(alignment: .bottom) { EditorRule() }
    }

    // MARK: - Ruler

    private var ruler: some View {
        Canvas { context, size in
            let step = rulerStep
            var time: TimeInterval = 0
            while time <= duration {
                let x = CGFloat(time) * viewModel.zoom
                let isMajor = Int((time / step).rounded()) % 5 == 0
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: size.height))
                tick.addLine(to: CGPoint(x: x, y: size.height - (isMajor ? 10 : 5)))
                context.stroke(tick, with: .color(.rsTextTertiary), lineWidth: 1)
                if isMajor {
                    let text = Text(label(for: time))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.rsTextTertiary)
                    context.draw(text, at: CGPoint(x: x + 3, y: 7), anchor: .leading)
                }
                time += step
            }
        }
        .frame(height: ProMetrics.rulerHeight)
        .background(Color.rsSurface1)
        .overlay(alignment: .bottom) { EditorRule() }
        .contentShape(Rectangle())
        .gesture(scrubGesture)
    }

    /// Seconds between small ticks, so the labels stay roughly 80 points apart at any zoom.
    private var rulerStep: TimeInterval {
        let candidates: [TimeInterval] = [0.2, 0.5, 1, 2, 5, 10, 30, 60]
        return candidates.first { CGFloat($0 * 5) * viewModel.zoom >= 80 } ?? 60
    }

    private func label(for time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }

    // MARK: - Tracks

    private var sceneTrack: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(pack.lines) { line in
                sceneClip(line)
                    .id(line.id)
                    .offset(x: x(line.startTime))
            }
        }
        .frame(height: ProMetrics.trackHeight)
        .overlay(alignment: .bottom) { EditorRule() }
    }

    private func sceneClip(_ line: DubLine) -> some View {
        let color = DubCharacterStyle.color(for: line.character, in: pack.characters)
        let isSelected = session.currentLine?.id == line.id
        return VStack(alignment: .leading, spacing: 1) {
            Text(String(format: "%03d  %@", line.index, line.character.uppercased()))
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text(line.caption)
                .font(.system(size: 10))
                .foregroundColor(.rsTextPrimary.opacity(0.85))
        }
        .lineLimit(1)
        .padding(.horizontal, 5)
        .frame(width: clipWidth(line), height: ProMetrics.trackHeight - 8, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.18)))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Color.proSelection : color.opacity(0.5), lineWidth: isSelected ? 2 : 1)
        )
        .clipped()
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.select(line) }
        .onTapGesture(count: 2) {
            viewModel.setMode(.line)
            viewModel.select(line)
        }
        .help("\(line.character): \(line.caption)")
    }

    private var takesTrack: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(pack.lines.filter { session.isRecorded($0) }) { line in
                takeClip(line)
                    .offset(x: x(line.startTime))
            }
            if viewModel.record.isRecording, let line = session.currentLine {
                liveTake(line)
                    .offset(x: x(line.startTime))
            }
        }
        .frame(height: ProMetrics.trackHeight)
        .overlay(alignment: .bottom) { EditorRule() }
    }

    private func takeClip(_ line: DubLine) -> some View {
        let isSelected = session.currentLine?.id == line.id
        return HStack(spacing: 4) {
            if session.hasBoothTake(line) {
                Image(systemName: "video.fill")
                    .font(.system(size: 8))
            }
            if let score = session.score(for: line) {
                Text(score.grade.badge)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            Spacer(minLength: 0)
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 5)
        .frame(width: clipWidth(line), height: ProMetrics.trackHeight - 8, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.rsRecord.opacity(0.55)))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Color.proSelection : Color.rsRecord, lineWidth: isSelected ? 2 : 1)
        )
        .clipped()
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.select(line) }
    }

    /// The take being recorded, growing across its line.
    private func liveTake(_ line: DubLine) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.rsRecord)
            .frame(
                width: max(2, clipWidth(line) * CGFloat(viewModel.record.pacingFraction(for: line))),
                height: ProMetrics.trackHeight - 8
            )
            .padding(.vertical, 4)
    }

    private var soundtrackTrack: some View {
        Canvas { context, size in
            guard !soundtrack.isEmpty else { return }
            let slot = size.width / CGFloat(soundtrack.count)
            let mid = size.height / 2
            var path = Path()
            for (index, value) in soundtrack.enumerated() {
                let height = max(1, CGFloat(value) * (size.height - 10))
                path.addRect(CGRect(x: CGFloat(index) * slot, y: mid - height / 2, width: max(1, slot - 0.5), height: height))
            }
            context.fill(path, with: .color(Color.proAudioClip))
        }
        .frame(height: ProMetrics.trackHeight)
        .background(Color.proAudioClip.opacity(0.12))
        .overlay(alignment: .bottom) { EditorRule() }
        .contentShape(Rectangle())
        .gesture(scrubGesture)
    }

    // MARK: - Playhead

    private var playhead: some View {
        let time = viewModel.playheadTime
        return ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.rsRecord.opacity(viewModel.record.isRecording ? 1 : 0.9))
                .frame(width: 1.5)
            PlayheadCap()
                .fill(Color.rsRecord)
                .frame(width: 11, height: 9)
        }
        .frame(width: 11)
        .offset(x: x(time) - 5.5)
        .allowsHitTesting(false)
    }

    /// Dragging on the ruler or the soundtrack moves the head, once the scene is in the viewer.
    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if viewModel.playback == nil { viewModel.setMode(.myDub) }
                viewModel.scrub(to: TimeInterval(value.location.x / viewModel.zoom))
            }
            .onEnded { _ in viewModel.endScrub() }
    }

    // MARK: - Geometry

    private func x(_ time: TimeInterval) -> CGFloat {
        CGFloat(max(0, time)) * viewModel.zoom
    }

    private func clipWidth(_ line: DubLine) -> CGFloat {
        max(4, CGFloat(line.duration) * viewModel.zoom - 1)
    }
}

/// The downward notch at the top of the playhead.
private nonisolated struct PlayheadCap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
