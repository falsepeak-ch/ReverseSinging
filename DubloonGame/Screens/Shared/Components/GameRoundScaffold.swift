//
//  GameRoundScaffold.swift
//  DubloonGame
//
//  The frame every round is played in: the stage on top, a deck that sizes itself to what the
//  round needs below, effects over both.
//

import SwiftUI
import SpriteKit

/// Lays out a round like a game-show screen.
///
/// The SpriteKit set fills the screen behind everything. The deck at the bottom is as tall as
/// its content, so it grows when the round has more to show (a result's breakdown) and
/// shrinks when it has less (waiting to record), and the stage takes whatever is left. The
/// round says where the host stands within that stage; when the stage changes size she
/// glides to her new spot. A clear SpriteKit layer on top carries stars and confetti.
struct GameRoundScaffold<Stage: View, Deck: View>: View {
    let mood: HostMood
    let fx: RoundFXScene
    /// Off while leaving would lose work, such as a video still rendering.
    var canGoBack = true
    /// Where the host stands, given the stage's frame in screen points.
    let placeHost: (CGRect) -> HostPlacement
    let onBack: () -> Void
    /// The stage's content, given the stage's size.
    @ViewBuilder let stage: (CGSize) -> Stage
    @ViewBuilder let deck: Deck

    /// Made once, see `SceneBox`.
    @StateObject private var stageBox = SceneBox(RoundStageScene(
        size: CGSize(width: 390, height: 844),
        reduceMotion: UIAccessibility.isReduceMotionEnabled
    ))
    private var scene: RoundStageScene { stageBox.scene }
    @State private var stageFrame: CGRect = .zero
    @State private var deckHeight: CGFloat = 0

    var body: some View {
        GeometryReader { screen in
            let compact = screen.size.height < 700
            ZStack(alignment: .top) {
                SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        GeometryReader { proxy in
                            stage(proxy.size)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }

                        GameRoundButton(symbol: "chevron.backward", label: Strings.Main.back, diameter: 48, action: onBack)
                            .disabled(!canGoBack)
                            .opacity(canGoBack ? 1 : 0.4)
                            .padding(.leading, 16)
                            .padding(.top, 4)
                    }
                    .frame(maxHeight: .infinity)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        stageFrame = frame
                    }

                    deckPanel(maxHeight: screen.size.height * 0.62, compact: compact)
                }

                SpriteView(scene: fx, options: [.allowsTransparency, .ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .background(Color.gameNavy.ignoresSafeArea())
        .onAppear { scene.set(mood) }
        .onChange(of: mood) { _, mood in scene.set(mood) }
        .onChange(of: stageFrame) { _, frame in
            guard frame.height > 0 else { return }
            scene.placement = placeHost(frame)
        }
        .hidesNavigationBar()
    }

    /// The pale sheet the controls sit on, rounded at the top with a grabber like a sheet.
    private func deckPanel(maxHeight: CGFloat, compact: Bool) -> some View {
        let content = VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 44, height: 5)
                .padding(.top, 10)
                .padding(.bottom, compact ? 8 : 12)
                .accessibilityHidden(true)
            deck
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }

        // Exactly as tall as its content, measured, up to the cap; past the cap (a short phone
        // with a long result) it scrolls rather than pushing controls off the screen.
        return ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    guard abs(height - deckHeight) > 0.5 else { return }
                    if deckHeight == 0 {
                        deckHeight = height
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { deckHeight = height }
                    }
                }
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(deckHeight <= maxHeight)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(max(deckHeight, 1), maxHeight))
        .frame(maxWidth: .infinity)
        .background {
            // A dark glass console with a lit cyan rim, so the controls sit in the show rather
            // than on a panel over it.
            let shape = UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
            shape
                .fill(LinearGradient(
                    colors: [Color(gameHex: 0x123A55).opacity(0.94), Color(gameHex: 0x07131D).opacity(0.97)],
                    startPoint: .top, endPoint: .bottom
                ))
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.gameCyan, lineWidth: 2.5).blur(radius: 3).opacity(0.9))
                .overlay(shape.stroke(Color.gameCyan.opacity(0.9), lineWidth: 1.5))
                .shadow(color: Color.gameCyan.opacity(0.35), radius: 16, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .environment(\.gameCompactDeck, compact)
    }
}
