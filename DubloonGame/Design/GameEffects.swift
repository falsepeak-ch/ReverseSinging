//
//  GameEffects.swift
//  DubloonGame
//
//  SwiftUI modifiers for the Metal effects in GameShaders.metal.
//

import SwiftUI

/// One clock for every effect, so a shine never restarts because a view was rebuilt.
enum GameClock {
    static let start = Date()

    static func time(_ date: Date) -> Float {
        Float(date.timeIntervalSince(start).truncatingRemainder(dividingBy: 3600))
    }
}

/// Runs `content` against the effect clock, frozen with Reduce Motion.
private struct ShaderClock<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let content: (Float) -> Content

    var body: some View {
        if reduceMotion {
            content(1.6)
        } else {
            TimelineView(.animation) { timeline in
                content(GameClock.time(timeline.date))
            }
        }
    }
}

extension View {
    /// A band of light sweeping across the view every few seconds.
    func gameShine(_ strength: Float = 0.45, isActive: Bool = true) -> some View {
        ShaderClock { time in
            self.visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.gameShine(.float2(proxy.size), .float(time), .float(strength)),
                    isEnabled: isActive
                )
            }
        }
    }

    /// Gold-foil sheen over the bright parts of the view.
    func gameFoil(_ strength: Float = 1, isActive: Bool = true) -> some View {
        ShaderClock { time in
            self.visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.gameFoil(.float2(proxy.size), .float(time), .float(strength)),
                    isEnabled: isActive
                )
            }
        }
    }

    /// The show's CRT: scanlines, a rolling bar, a bulge and fringing.
    func gameCRT(_ intensity: Float = 1) -> some View {
        ShaderClock { time in
            self.visualEffect { content, proxy in
                content.layerEffect(
                    ShaderLibrary.gameCRT(.float2(proxy.size), .float(time), .float(intensity)),
                    maxSampleOffset: CGSize(width: 4, height: 4)
                )
            }
        }
    }

    /// A jelly wobble, `amount` points at its widest.
    func gameWobble(_ amount: Float, isActive: Bool = true) -> some View {
        ShaderClock { time in
            self.visualEffect { content, proxy in
                content.distortionEffect(
                    ShaderLibrary.gameWobble(.float2(proxy.size), .float(time), .float(amount)),
                    maxSampleOffset: CGSize(width: CGFloat(amount), height: CGFloat(amount)),
                    isEnabled: isActive && amount > 0
                )
            }
        }
    }

    /// A pulse of `tint` light from the middle of the view.
    func gameGlowPulse(_ tint: Color, strength: Float = 0.35, isActive: Bool = true) -> some View {
        ShaderClock { time in
            self.visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.gameGlowPulse(.float2(proxy.size), .float(time), .color(tint), .float(strength)),
                    isEnabled: isActive
                )
            }
        }
    }
}
