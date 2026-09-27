//
//  VerdictStamp.swift
//  ReverseSinging
//
//  The rubber stamp that slams down on a result, and the confetti that follows a pass
//

import SwiftUI

/// APPROVED, NAILED IT, FAILED… dropped from three times its size, tilted, and shaken once,
/// like something slammed on a desk. Mirrors the stamp drawn into the video.
struct VerdictStamp: View {
    let verdict: ImitationVerdict
    /// How long after appearing it lands.
    var delay: TimeInterval = 0.9
    var onLand: () -> Void = {}

    @State private var hasLanded = false
    @State private var shake: CGFloat = 0

    var body: some View {
        Text(verdict.word)
            .font(.system(size: 40, weight: .black))
            .tracking(2)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundColor(verdict.tint.color)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(verdict.tint.color, lineWidth: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(verdict.tint.color.opacity(0.7), lineWidth: 1.5)
                    .padding(6)
            )
            .rotationEffect(.degrees(-12))
            .offset(x: shake)
            .scaleEffect(hasLanded ? 1 : 3)
            .opacity(hasLanded ? 1 : 0)
            .task(id: verdict.word) {
                hasLanded = false
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.16)) { hasLanded = true }
                try? await Task.sleep(nanoseconds: 160_000_000)
                onLand()
                withAnimation(.interpolatingSpring(stiffness: 900, damping: 8)) { shake = 10 }
                try? await Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.interpolatingSpring(stiffness: 900, damping: 12)) { shake = 0 }
            }
            .accessibilityLabel(verdict.word)
    }
}

/// The burst from `ConfettiSimulation`, drawn live. The same seed throws the same burst the
/// video does.
struct ConfettiBurst: View {
    let seed: UInt64
    /// When the burst starts.
    let start: Date

    var body: some View {
        let simulation = ConfettiSimulation(seed: seed, count: 80)
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.45)
                for piece in simulation.pieces(at: t, in: size, from: origin) {
                    let rgb = ConfettiSimulation.palette[piece.colorIndex]
                    var pieceContext = context
                    pieceContext.translateBy(x: piece.position.x, y: piece.position.y)
                    pieceContext.rotate(by: .radians(piece.rotation))
                    let rect = CGRect(
                        x: -piece.size.width / 2, y: -piece.size.height / 2,
                        width: piece.size.width, height: piece.isRound ? piece.size.width : piece.size.height
                    )
                    let shape = piece.isRound ? Path(ellipseIn: rect) : Path(rect)
                    pieceContext.fill(shape, with: .color(Color(red: rgb.red, green: rgb.green, blue: rgb.blue).opacity(piece.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
