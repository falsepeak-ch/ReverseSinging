//
//  ConfettiSimulation.swift
//  ReverseSinging
//
//  Confetti as a pure function of time, so the screen and the video throw the same burst
//

import CoreGraphics
import Foundation

/// A burst of confetti, computed rather than animated.
///
/// Every particle's position is a closed-form function of `(seed, t)`, so the result screen's
/// `Canvas` and the video renderer draw exactly the same burst, and a frame can be drawn in
/// any order. No state, nothing to tick.
nonisolated struct ConfettiSimulation: Sendable {

    struct Piece: Sendable {
        var position: CGPoint
        var rotation: CGFloat
        var size: CGSize
        var colorIndex: Int
        var isRound: Bool
        var opacity: CGFloat
    }

    /// The colours the pieces cycle through: the app's state colours, the highlight, and white.
    static let palette: [(red: CGFloat, green: CGFloat, blue: CGFloat)] = [
        (0.239, 0.639, 0.365),
        (0.780, 0.604, 0.227),
        (0.898, 0.282, 0.302),
        (0.478, 0.573, 0.616),
        (0.910, 0.918, 0.925),
    ]

    /// How long a burst lasts before the last piece has faded.
    static let lifetime: TimeInterval = 2.6

    private struct Seed {
        var angle: CGFloat
        var speed: CGFloat
        var spin: CGFloat
        var drift: CGFloat
        var size: CGSize
        var colorIndex: Int
        var isRound: Bool
        var delay: CGFloat
    }

    private let seeds: [Seed]

    init(seed: UInt64, count: Int = 110) {
        var generator = SplitMix64(seed: seed)
        seeds = (0..<count).map { index in
            Seed(
                // Up and outward, a fan about 110° wide.
                angle: -.pi / 2 + CGFloat.random(in: -0.95...0.95, using: &generator),
                speed: CGFloat.random(in: 0.55...1.25, using: &generator),
                spin: CGFloat.random(in: -9...9, using: &generator),
                drift: CGFloat.random(in: 0...(2 * .pi), using: &generator),
                size: CGSize(
                    width: CGFloat.random(in: 0.012...0.022, using: &generator),
                    height: CGFloat.random(in: 0.02...0.036, using: &generator)
                ),
                colorIndex: index % Self.palette.count,
                isRound: CGFloat.random(in: 0...1, using: &generator) < 0.25,
                delay: CGFloat.random(in: 0...0.12, using: &generator)
            )
        }
    }

    /// The pieces `t` seconds after the burst, in a canvas of `size`, thrown from `origin`
    /// (in the canvas's own points).
    func pieces(at t: TimeInterval, in size: CGSize, from origin: CGPoint) -> [Piece] {
        guard t >= 0, t < Self.lifetime else { return [] }

        // Distances scale with the canvas's width, so the phone and the 1080-wide video frame
        // look like the same burst.
        let scale = size.width
        let gravity: CGFloat = 1.35
        let drag: CGFloat = 1.6

        return seeds.compactMap { seed in
            let time = CGFloat(t) - seed.delay
            guard time > 0 else { return nil }

            // Velocity decays exponentially under drag; position is its integral, plus gravity
            // pulling at a terminal-ish pace so pieces flutter down rather than plummet.
            let decay = (1 - exp(-drag * time)) / drag
            let vx = cos(seed.angle) * seed.speed
            let vy = sin(seed.angle) * seed.speed
            let flutter = sin(time * 6 + seed.drift) * 0.025

            let x = origin.x + (vx * decay + flutter) * scale
            let y = origin.y + (vy * decay + gravity * 0.5 * time * time * 0.35) * scale

            let fadeStart = CGFloat(Self.lifetime) - 0.7
            let opacity = time < fadeStart ? 1 : max(0, 1 - (time - fadeStart) / 0.7)

            return Piece(
                position: CGPoint(x: x, y: y),
                rotation: seed.spin * time,
                size: CGSize(width: seed.size.width * scale, height: seed.size.height * scale),
                colorIndex: seed.colorIndex,
                isRound: seed.isRound,
                opacity: opacity
            )
        }
    }
}

/// A tiny seeded generator, so a burst is the same burst every time it is drawn.
nonisolated struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
