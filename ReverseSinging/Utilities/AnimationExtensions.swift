//
//  AnimationExtensions.swift
//  ReverseSinging
//
//  Reusable animation modifiers and extensions
//

import SwiftUI

// MARK: - Animation Presets

extension Animation {
    static let rsSpring = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let rsSmoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let rsBouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)
    static let rsSmooth = Animation.easeInOut(duration: 0.3)
    static let rsQuick = Animation.easeOut(duration: 0.2)
}

// MARK: - Slide In Animation

struct SlideInModifier: ViewModifier {
    let delay: Double
    @State private var offset: CGFloat = 50
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.rsSpring.delay(delay)) {
                    offset = 0
                    opacity = 1
                }
            }
    }
}

extension View {
    func slideIn(delay: Double = 0) -> some View {
        modifier(SlideInModifier(delay: delay))
    }
}

// MARK: - Scale In Animation

struct ScaleInModifier: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.rsBouncy.delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

extension View {
    func scaleIn(delay: Double = 0) -> some View {
        modifier(ScaleInModifier(delay: delay))
    }
}

// MARK: - Fade In Animation

struct FadeInModifier: ViewModifier {
    let delay: Double
    let duration: Double

    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) {
                    opacity = 1.0
                }
            }
    }
}

extension View {
    func fadeIn(delay: Double = 0, duration: Double = 0.3) -> some View {
        modifier(FadeInModifier(delay: delay, duration: duration))
    }
}

// MARK: - Bounce Animation

struct BounceModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.rsSpring) {
                    scale = 1.1
                }
                withAnimation(.rsSpring.delay(0.1)) {
                    scale = 1.0
                }
            }
    }
}

extension View {
    func bounceOnAppear() -> some View {
        modifier(BounceModifier())
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Pulse Animation

struct PulseModifier: ViewModifier {
    let color: Color
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulse(color: Color = .rsTurquoise) -> some View {
        modifier(PulseModifier(color: color))
    }
}

// MARK: - Card Animation

struct AnimatedCardModifier: ViewModifier {
    let delay: Double
    @State private var offset: CGFloat = 30
    @State private var scale: CGFloat = 0.95
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.rsSpring.delay(delay)) {
                    offset = 0
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

extension View {
    func animatedCard(delay: Double = 0) -> some View {
        modifier(AnimatedCardModifier(delay: delay))
    }
}

// MARK: - Rotate Animation

extension View {
    func rotateOnAppear(degrees: Double = 360, duration: Double = 1.0) -> some View {
        modifier(RotateModifier(degrees: degrees, duration: duration))
    }
}

struct RotateModifier: ViewModifier {
    let degrees: Double
    let duration: Double
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    rotation = degrees
                }
            }
    }
}

// MARK: - Conditional Animation

extension View {
    func conditionalAnimation<V: Equatable>(_ animation: Animation?, value: V, condition: Bool) -> some View {
        if condition {
            return AnyView(self.animation(animation, value: value))
        } else {
            return AnyView(self)
        }
    }
}
