//
//  EditorChrome.swift
//  ReverseSinging
//
//  The shared vocabulary of the cinema-editor interface: panels separated by
//  hairlines, tracked section labels, tick rulers and film grain.
//

import SwiftUI
import UIKit

// MARK: - Metrics

enum EditorMetrics {
    /// Editors use tight corners. Anything rounder reads as a consumer app.
    static let radius: CGFloat = 6
    static let radiusLarge: CGFloat = 10
    static let hairline: CGFloat = 1
    static let rowHeight: CGFloat = 56
    static let gutter: CGFloat = 16
    /// Letter-spacing for uppercase section labels.
    static let tracking: CGFloat = 1.2
    /// Screen header, status bar included. Content below it clears this much.
    static let headerHeight: CGFloat = 96
}

// MARK: - Panels

extension View {

    /// A panel: flat fill, hairline border, tight radius. No shadow — depth in this
    /// design comes from the surface ramp and the stroke, never from blur.
    func editorPanel(
        _ surface: Color = .rsSurface1,
        radius: CGFloat = EditorMetrics.radius,
        stroke: Color = .rsStroke
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: EditorMetrics.hairline)
            )
    }

    /// A panel that reads as selected or armed.
    func editorPanelActive(_ tint: Color) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .strokeBorder(tint.opacity(0.55), lineWidth: EditorMetrics.hairline)
            )
    }

    /// Uppercase, tracked, muted — for section headers and control labels.
    func editorLabelStyle(_ color: Color = .rsTextTertiary) -> some View {
        self
            .font(.rsSectionLabel)
            .tracking(EditorMetrics.tracking)
            .foregroundColor(color)
            .textCase(.uppercase)
    }

    /// Overlays fine film grain. Subtle by design: visible as texture, never as noise.
    func filmGrain(opacity: Double = 0.05) -> some View {
        overlay(FilmGrain(opacity: opacity).allowsHitTesting(false))
    }

    /// Darkens the edges so full-bleed stills sit in the frame rather than on it.
    func cinemaVignette(strength: Double = 0.55) -> some View {
        overlay(CinemaVignette(strength: strength).allowsHitTesting(false))
    }
}

// MARK: - Section Header

/// A tracked label with a rule running to the trailing edge, and an optional trailing value.
struct EditorSectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .editorLabelStyle()

            Rectangle()
                .fill(Color.rsStroke)
                .frame(height: EditorMetrics.hairline)

            if let trailing {
                Text(trailing)
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextTertiary)
            }
        }
    }
}

// MARK: - Rules

struct EditorRule: View {
    var color: Color = .rsStroke

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: EditorMetrics.hairline)
    }
}

// MARK: - Tick Ruler

/// The timeline ruler: a minor tick each second, a major tick each `majorEvery`.
/// Purely decorative, but it is what makes a progress bar read as a timeline.
struct EditorTickRuler: View {
    let duration: TimeInterval
    var majorEvery: TimeInterval = 30

    var body: some View {
        GeometryReader { geometry in
            let ticks = max(1, Int(duration / majorEvery))
            let spacing = geometry.size.width / CGFloat(ticks)

            ZStack(alignment: .topLeading) {
                ForEach(0...ticks, id: \.self) { index in
                    Rectangle()
                        .fill(Color.rsStroke)
                        .frame(width: EditorMetrics.hairline, height: index % 2 == 0 ? 8 : 5)
                        .offset(x: spacing * CGFloat(index))
                }
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Playhead Track

/// A timeline scrubber: a thin track, a bright playhead, and a light-on-dark fill.
struct EditorTrack: View {
    let progress: Double
    var tint: Color = .rsTextPrimary
    var height: CGFloat = 3
    var showsPlayhead: Bool = true

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(progress, 0), 1)
            let x = geometry.size.width * clamped

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.rsSurface3)
                    .frame(height: height)

                Rectangle()
                    .fill(tint)
                    .frame(width: x, height: height)

                if showsPlayhead {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 2, height: height + 8)
                        .offset(x: max(0, x - 1))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: height + 8)
    }
}

// MARK: - Record Indicator

/// The armed-and-rolling dot. Pulses only while actually recording.
struct EditorRecordDot: View {
    let isActive: Bool
    var size: CGFloat = 8

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(isActive ? Color.rsRecord : Color.rsTextTertiary)
            .frame(width: size, height: size)
            .opacity(isActive && isPulsing ? 0.35 : 1)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onChange(of: isActive) { _, active in
                isPulsing = active
            }
            .onAppear { isPulsing = isActive }
    }
}

// MARK: - Level Rail

/// A horizontal segmented meter, like the master strip on a desk. Idle it reads as a
/// dotted rule, which is why the monitor panel never looks empty.
struct LevelRail: View {
    let level: CGFloat
    var isActive: Bool
    var segments: Int = 28

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { index in
                let position = CGFloat(index) / CGFloat(segments - 1)
                let isLit = isActive && level >= position

                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(isLit ? segmentColor(at: position) : Color.rsSurface3)
                    .frame(width: 3, height: isLit ? 14 : 6)
            }
        }
        .frame(height: 14)
        .animation(.easeOut(duration: 0.1), value: level)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    /// The last fifth runs hot, the way a real meter warns before clipping.
    private func segmentColor(at position: CGFloat) -> Color {
        if position > 0.86 { return .rsRecord }
        if position > 0.72 { return .rsCaution }
        return .rsTextSecondary
    }
}

// MARK: - Film Grain

/// Tiles the supplied 512px grain plate. Kept at a few percent: it should read as
/// texture on the panels, never as noise over the picture.
struct FilmGrain: View {
    var opacity: Double = 0.05

    var body: some View {
        Image("film-grain")
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.overlay)
            .ignoresSafeArea()
    }
}

// MARK: - Vignette

/// The supplied 2048px vignette plate, stretched over the frame.
struct CinemaVignette: View {
    var strength: Double = 0.55

    var body: some View {
        Image("vignette")
            .resizable()
            .opacity(strength)
            .ignoresSafeArea()
    }
}

// MARK: - Toolbar Button

/// Square, bordered, monochrome — the toolbar of a tool rather than a tab bar.
/// Shared so the header reads identically on every screen that has one.
struct EditorToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.rsTextSecondary)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.rsSurface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
                )
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Screen Header

/// The bar at the top of a pushed screen: back, the screen's own title, its actions.
///
/// Pushed screens name themselves rather than repeat the app logo — the branding
/// belongs to the menu the user came from, and a title is what tells them which
/// game they are in. Sized to swallow the status bar, so callers place it at the
/// top of a stack that ignores the top safe area.
struct EditorScreenHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 10) {
                EditorToolbarButton(
                    icon: "chevron.left",
                    label: Strings.Main.back,
                    action: onBack
                )

                Text(title)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 8)

                trailing
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.bottom, 10)
        }
        .frame(height: EditorMetrics.headerHeight)
        .background(Color.rsSurface1)
        .overlay(alignment: .bottom) { EditorRule() }
    }
}

extension EditorScreenHeader where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}
