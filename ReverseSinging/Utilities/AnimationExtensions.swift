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
