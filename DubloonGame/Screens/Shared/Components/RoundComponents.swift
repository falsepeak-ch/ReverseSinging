//
//  RoundComponents.swift
//  DubloonGame
//
//  What every round shows: the countdown card, the comparison display, the score reveal.
//

import SwiftUI
import DubScoring

// MARK: - Countdown card

/// The flip card on the stage. Between takes it shows what the round is about (a symbol or a
/// still); through the count it flips to 3, 2, 1; while the mic is open it shows the clock.
struct CountdownCard<Face: View>: View {
    let countdown: Int?
    let isRecording: Bool
    /// Seconds left in the take, while recording.
    let secondsLeft: Int?
    @ViewBuilder let face: Face

    @State private var flip = 0.0

    var body: some View {
        ZStack {
            // The ring the card hangs in, like the dial behind the number in a game show.
            Circle()
                .strokeBorder(Color.gameNavy, lineWidth: 4)
                .background(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 16))
                .padding(-26)

            Group {
                if let countdown {
                    Text("\(countdown)")
                        .font(.game(118, weight: .black))
                        .foregroundStyle(countdown == 1 ? Color.gameRed : Color.gameNavy)
                        .monospacedDigit()
                        .id(countdown)
                } else if isRecording, let secondsLeft {
                    VStack(spacing: 2) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(Color.gameRed)
                            .symbolEffect(.pulse)
                        Text("\(secondsLeft)")
                            .font(.game(78, weight: .black))
                            .foregroundStyle(Color.gameNavy)
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    }
                } else {
                    face
                }
            }
            .frame(width: 150, height: 160)
            .gameCard(fill: .white, radius: 18, lip: 6)
            .rotation3DEffect(.degrees(flip), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        }
        .frame(width: 150, height: 166)
        .onChange(of: countdown) { _, value in
            guard value != nil else { return }
            // Each beat flips the card over its top edge, like a scoreboard number.
            flip = -90
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) { flip = 0 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(countdown.map { "\($0)" } ?? "")
    }
}

// MARK: - Comparison display

/// The black screen in the deck: the target in cyan, your take laid over it in magenta, a red
/// playhead. Both are drawn on the same time axis, so the overlap is the score you can see.
struct ComparisonDisplay: View {
    let reference: [Float]
    /// How much of the width the reference covers, when the axis runs longer than it.
    var referenceSpan: Double = 1
    let take: [Float]?
    /// How wide the take is drawn against the reference: a take that ran long draws past it.
    var takeSpan: Double = 1
    /// 0...1, or nil when nothing is playing or recording.
    let progress: Double?
    let onTap: (() -> Void)?

    var body: some View {
        Canvas { context, size in
            let mid = size.height / 2
            let inset: CGFloat = 10
            let width = size.width - inset * 2

            // A faint centre line, like a scope.
            var line = Path()
            line.move(to: CGPoint(x: inset, y: mid))
            line.addLine(to: CGPoint(x: size.width - inset, y: mid))
            context.stroke(line, with: .color(.white.opacity(0.5)), lineWidth: 1)

            draw(reference, in: &context, x: inset, width: width * referenceSpan, mid: mid, height: size.height, color: .gameCyan, glow: 0.35)
            if let take, !take.isEmpty {
                draw(take, in: &context, x: inset, width: width * takeSpan, mid: mid, height: size.height, color: .gameMagenta, glow: 0.3)
            }

            if let progress {
                let x = inset + width * progress
                var head = Path()
                head.move(to: CGPoint(x: x, y: 4))
                head.addLine(to: CGPoint(x: x, y: size.height - 4))
                context.stroke(head, with: .color(.gameRed), lineWidth: 3)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gameCyan)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.gameNavy, lineWidth: 3)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    /// Mirrored bars, a soft halo first and the solid shape on top.
    private func draw(_ samples: [Float], in context: inout GraphicsContext, x: CGFloat, width: CGFloat, mid: CGFloat, height: CGFloat, color: Color, glow: Double) {
        guard !samples.isEmpty else { return }
        let step = width / CGFloat(samples.count)
        var solid = Path()
        var halo = Path()
        for (index, sample) in samples.enumerated() {
            let amplitude = CGFloat(max(0.02, min(1, sample))) * (height / 2 - 8)
            let rect = CGRect(x: x + CGFloat(index) * step, y: mid - amplitude, width: max(step * 0.78, 1), height: amplitude * 2)
            solid.addRoundedRect(in: rect, cornerSize: CGSize(width: step * 0.3, height: step * 0.3))
            halo.addRect(rect.insetBy(dx: -step * 0.4, dy: -5))
        }
        context.fill(halo, with: .color(color.opacity(glow)))
        context.fill(solid, with: .color(color))
    }
}

// MARK: - Score reveal

/// The result, revealed like a game show: the number rolls up, then up to three stars stamp
/// down one after another, then the verdict.
struct ScoreReveal: View {
    let score: Double
    let grade: DubGrade
    let verdict: String
    var onStar: ((Int) -> Void)? = nil

    @State private var shown: Double = 0
    @State private var starsLit = 0
    @State private var verdictIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stars: Int {
        switch grade {
        case .perfect, .great: return 3
        case .good: return 2
        case .close: return 1
        case .rough: return 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    let lit = index < starsLit
                    Image(systemName: lit ? "star.fill" : "star")
                        .font(.system(size: index == 1 ? 40 : 32, weight: .black))
                        .foregroundStyle(lit ? Color.gameGold : Color.white.opacity(0.85))
                        .shadow(color: .gameNavy, radius: 0, x: 0, y: 3)
                        .scaleEffect(index < starsLit ? 1 : 0.8)
                        .offset(y: index == 1 ? -8 : 0)
                }
            }

            OutlinedText(text: "\(Int(shown.rounded()))", size: 64, color: .white)

            OutlinedText(text: verdict.uppercased(), size: 26, color: stars >= 2 ? .gameGold : (stars == 1 ? .gameCyan : .gameCoral))
                .scaleEffect(verdictIn ? 1 : 2.2)
                .opacity(verdictIn ? 1 : 0)
                .rotationEffect(.degrees(verdictIn ? -4 : -12))
        }
        .task(id: score) { await reveal() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(score.rounded())), \(verdict)")
    }

    private func reveal() async {
        shown = 0
        starsLit = 0
        verdictIn = false
        guard !reduceMotion else {
            shown = score
            starsLit = stars
            verdictIn = true
            return
        }
        // The number rolls up over most of a second, ticking.
        let steps = 24
        for step in 1...steps {
            try? await Task.sleep(for: .milliseconds(32))
            withAnimation(.linear(duration: 0.03)) { shown = score * Double(step) / Double(steps) }
            if step.isMultiple(of: 4) { HapticManager.shared.soft() }
        }
        for star in 0..<stars {
            try? await Task.sleep(for: .milliseconds(230))
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { starsLit = star + 1 }
            HapticManager.shared.medium()
            onStar?(star)
        }
        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { verdictIn = true }
    }
}

extension DubGrade {
    /// Whether the host cheers. Matches the imitation verdict's confetti line.
    var celebrates: Bool { self == .perfect || self == .great || self == .good }
}
