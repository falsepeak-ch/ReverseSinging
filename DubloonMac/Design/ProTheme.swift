//
//  ProTheme.swift
//  DubloonMac
//
//  The Mac's editing-suite chrome: panel headers, the LCD dashboard, transport keys and clip
//  colours, on top of the shared editor palette.
//

import SwiftUI

/// Sizes the Mac panels share. Denser than the phone's `EditorMetrics`: a pointer is precise
/// and the window is big, so the chrome gets out of the picture's way.
enum ProMetrics {
    static let panelHeaderHeight: CGFloat = 30
    static let trackHeaderWidth: CGFloat = 92
    static let trackHeight: CGFloat = 46
    static let rulerHeight: CGFloat = 24
    static let inspectorWidth: CGFloat = 280
    static let radius: CGFloat = 5
}

extension Color {
    /// The viewer's surround: darker than any panel, so the picture is the brightest thing.
    static let proViewer = Color(red: 0.035, green: 0.038, blue: 0.043)

    /// A clip that is selected wears the suite's selection outline.
    static let proSelection = Color(red: 0.965, green: 0.776, blue: 0.227)   // #F6C63A

    /// Audio clips are green in every editor worth the name.
    static let proAudioClip = Color(red: 0.180, green: 0.478, blue: 0.325)   // #2E7A53
}

// MARK: - Panel Header

/// The strip across the top of every panel: a small caps title, and whatever controls the
/// panel keeps to itself on the right.
struct ProPanelHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .editorLabelStyle(.rsTextSecondary)
                .lineLimit(1)
                .fixedSize()

            if let subtitle {
                Text(subtitle)
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, 12)
        .frame(height: ProMetrics.panelHeaderHeight)
        .background(Color.rsSurface2)
        .overlay(alignment: .bottom) { EditorRule() }
    }
}

extension ProPanelHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - LCD Dashboard

/// The dashboard in the middle of the toolbar: a status lamp, a big timecode and a second
/// readout, on a recessed glass panel like the one in the editors this is modelled on.
struct ProDashboard: View {
    enum Lamp {
        case idle, recording, playing, countIn

        var color: Color {
            switch self {
            case .idle: .rsTextTertiary
            case .recording: .rsRecord
            case .playing: .rsGood
            case .countIn: .rsCaution
            }
        }

        var label: String {
            switch self {
            case .idle: Strings.Main.State.idle
            case .recording: Strings.Main.State.recording
            case .playing: Strings.Main.State.playing
            case .countIn: Strings.Main.State.countingIn
            }
        }
    }

    let lamp: Lamp
    let timecode: String
    var detail: String?
    /// Microphone level, 0...1, drawn as a meter at the right edge. Nil hides the meter.
    var level: Float?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(lamp.color)
                    .frame(width: 7, height: 7)
                    .shadow(color: lamp == .idle ? .clear : lamp.color.opacity(0.8), radius: 3)
                Text(lamp.label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(lamp == .idle ? .rsTextTertiary : lamp.color)
                    .frame(minWidth: 34, alignment: .leading)
            }

            Text(timecode)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .foregroundColor(.rsTextPrimary)
                .monospacedDigit()

            if let detail {
                Rectangle()
                    .fill(Color.rsStroke)
                    .frame(width: 1, height: 16)
                Text(detail)
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextSecondary)
                    .lineLimit(1)
            }

            if let level {
                ProLevelMeter(level: level)
                    .frame(width: 44, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// A horizontal segment meter, green to amber to red.
struct ProLevelMeter: View {
    let level: Float

    private let segments = 12

    var body: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 1.5
            let width = (geometry.size.width - gap * CGFloat(segments - 1)) / CGFloat(segments)
            HStack(spacing: gap) {
                ForEach(0..<segments, id: \.self) { index in
                    let position = Double(index) / Double(segments - 1)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color(at: position).opacity(Double(level) >= position - 0.001 && level > 0.01 ? 1 : 0.18))
                        .frame(width: width)
                }
            }
        }
        .animation(.linear(duration: 0.06), value: level)
    }

    private func color(at position: Double) -> Color {
        switch position {
        case ..<0.65: .rsGood
        case ..<0.85: .rsCaution
        default: .rsRecord
        }
    }
}

// MARK: - Transport

/// One key on a transport bar: an SF Symbol in a recessed square.
struct ProTransportButton: View {
    let icon: String
    let label: String
    var isActive = false
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive || (isHovered && isEnabled) ? .rsTextPrimary : .rsTextSecondary)
                .frame(width: 32, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: ProMetrics.radius, style: .continuous)
                        .fill(isActive || (isHovered && isEnabled) ? Color.rsSurface3 : Color.rsSurface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ProMetrics.radius, style: .continuous)
                        .strokeBorder(isActive ? Color.rsStrokeStrong : Color.rsStroke, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(ProPressStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// The record key: the only round control, and the only red one.
struct ProRecordButton: View {
    @State private var isHovered = false
    let isRecording: Bool
    var isCountingIn = false
    var level: Float = 0
    var size: CGFloat = 30
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.rsRecord.opacity(isRecording ? 0.2 : 0))
                    .scaleEffect(1 + CGFloat(level) * 0.3)
                Circle()
                    .strokeBorder(Color.rsRecord.opacity(isCountingIn ? 1 : 0.55), lineWidth: 1.5)
                RoundedRectangle(cornerRadius: isRecording ? 3 : size, style: .continuous)
                    .fill(Color.rsRecord)
                    .frame(
                        width: isRecording ? size * 0.36 : size * 0.66,
                        height: isRecording ? size * 0.36 : size * 0.66
                    )
            }
            .frame(width: size, height: size)
            .brightness(isHovered ? 0.08 : 0)
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.12), value: level)
            .animation(.rsQuick, value: isRecording)
        }
        .buttonStyle(ProPressStyle())
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Dims a control while it is held, the way a hardware key goes down.
struct ProPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

// MARK: - Inspector

/// A titled group inside an inspector, in the suite's style rather than a grouped form's.
struct ProInspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .editorLabelStyle(.rsTextTertiary)

            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { EditorRule() }
    }
}

/// A label and a value on one line, the value in the timecode face.
struct ProInspectorRow: View {
    let label: String
    let value: String
    var valueColor: Color = .rsTextPrimary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.rsMeta)
                .foregroundColor(.rsTextSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.rsTimecodeSmall)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Time

extension TimeInterval {
    /// Hours:minutes:seconds:frames at 25 fps, the way the suite reads time.
    var proTimecode: String {
        let clamped = Swift.max(0, self)
        let totalFrames = Int((clamped * 25).rounded(.down))
        let frames = totalFrames % 25
        let seconds = (totalFrames / 25) % 60
        let minutes = (totalFrames / 1500) % 60
        let hours = totalFrames / 90000
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    /// Minutes and seconds with tenths, for short clips.
    var proShortTime: String {
        let clamped = Swift.max(0, self)
        let minutes = Int(clamped) / 60
        let seconds = clamped - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, seconds)
    }
}

// MARK: - Waveform

/// A clip's waveform in the clip's own colour, mirrored about the centre like an audio clip in
/// a timeline, brighter behind the playhead.
struct ProWaveform: View {
    let samples: [Float]
    let tint: Color
    /// 0...1, or nil when not playing.
    var progress: Double?

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }
            let slot = size.width / CGFloat(samples.count)
            let barWidth = max(1, slot * 0.7)
            let mid = size.height / 2
            let head = progress.map { CGFloat($0) * size.width }
            var played = Path()
            var unplayed = Path()
            for (index, value) in samples.enumerated() {
                let height = max(2, CGFloat(value) * size.height)
                let rect = CGRect(x: CGFloat(index) * slot + (slot - barWidth) / 2, y: mid - height / 2, width: barWidth, height: height)
                if let head, rect.midX <= head {
                    played.addRoundedRect(in: rect, cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2))
                } else {
                    unplayed.addRoundedRect(in: rect, cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2))
                }
            }
            context.fill(unplayed, with: .color(tint.opacity(progress == nil ? 0.85 : 0.45)))
            context.fill(played, with: .color(.white.opacity(0.92)))
            if let head {
                context.fill(Path(CGRect(x: head - 0.75, y: 0, width: 1.5, height: size.height)), with: .color(.rsRecord))
            }
        }
    }
}

// MARK: - Panes

/// A hairline between two panes that can be dragged to resize them.
///
/// The suite's own splitter rather than `HSplitView`/`VSplitView`: those size their panes from
/// the content's intrinsic width, so a wide table shoves the viewer off the window.
struct ProResizeHandle: View {
    enum Direction {
        /// A vertical line, dragged left and right.
        case horizontal
        /// A horizontal line, dragged up and down.
        case vertical
    }

    let direction: Direction
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// True when dragging towards the leading or top edge makes the pane bigger.
    var inverted = false

    @State private var start: Double?

    var body: some View {
        Rectangle()
            .fill(Color.rsStroke)
            .frame(width: direction == .horizontal ? 1 : nil, height: direction == .vertical ? 1 : nil)
            .overlay {
                Color.clear
                    .frame(width: direction == .horizontal ? 9 : nil, height: direction == .vertical ? 9 : nil)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        let cursor: NSCursor = direction == .horizontal ? .resizeLeftRight : .resizeUpDown
                        inside ? cursor.push() : NSCursor.pop()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { drag in
                                let origin = start ?? value
                                if start == nil { start = value }
                                let delta = direction == .horizontal ? drag.translation.width : drag.translation.height
                                value = min(max(origin + Double(inverted ? -delta : delta), range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in start = nil }
                    )
            }
            .zIndex(1)
    }
}

// MARK: - Inspector Pane

/// Pane sizing shared by the browsers and the inspector.
enum ProPane {
    /// The width the user dragged a pane to, given up as the window narrows so the centre
    /// keeps `leaving` points, and never below `minimum`.
    static func width(_ preferred: Double, of total: CGFloat, leaving centre: CGFloat, minimum: CGFloat) -> CGFloat {
        max(minimum, min(CGFloat(preferred), total - centre))
    }
}

extension View {
    /// Docks an inspector on the trailing edge, behind a handle the user can drag.
    ///
    /// Not SwiftUI's `.inspector`: inside a split view's detail column, next to AppKit split
    /// views, it sends the window into an endless constraint pass and AppKit kills the app.
    func proInspector<Inspector: View>(
        isPresented: Bool,
        @ViewBuilder content: () -> Inspector
    ) -> some View {
        modifier(ProInspectorModifier(isPresented: isPresented, inspector: content()))
    }
}

private struct ProInspectorModifier<Inspector: View>: ViewModifier {
    let isPresented: Bool
    let inspector: Inspector

    @AppStorage("mac.inspectorWidth") private var width: Double = Double(ProMetrics.inspectorWidth)

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                if isPresented {
                    ProResizeHandle(
                        direction: .horizontal,
                        value: $width,
                        range: 240...420,
                        inverted: true
                    )
                    inspector
                        .frame(width: ProPane.width(width, of: geometry.size.width, leaving: 640, minimum: 220))
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .trailing))
                }
            }
        }
    }
}

// MARK: - Hover

extension View {
    /// Lifts a tile a touch under the pointer, the way a clip in a browser answers the mouse.
    func proHoverLift() -> some View {
        modifier(ProHoverLift())
    }
}

private struct ProHoverLift: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovered ? 0.05 : 0)
            .scaleEffect(isHovered ? 1.015 : 1)
            .shadow(color: .black.opacity(isHovered ? 0.35 : 0), radius: 8, y: 4)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
