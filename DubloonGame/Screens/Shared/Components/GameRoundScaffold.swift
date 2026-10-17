//
//  GameRoundScaffold.swift
//  DubloonGame
//
//  The frame every round is played in: the stage on top, the deck below, effects over both.
//

import SwiftUI
import SpriteKit

/// Lays out a round like a game-show screen.
///
/// The SpriteKit set fills the screen behind everything; the round's stage content (the card,
/// the picture, the caption) sits on its top part; the pale deck below holds the comparison
/// display and the controls. A clear SpriteKit layer on top carries stars and confetti.
struct GameRoundScaffold<Stage: View, Deck: View>: View {
    let mood: HostMood
    let fx: RoundFXScene
    /// The share of the screen the stage takes, above the deck.
    var stageShare: CGFloat = 0.52
    /// Off while leaving would lose work, such as a video still rendering.
    var canGoBack = true
    let onBack: () -> Void
    @ViewBuilder let stage: Stage
    @ViewBuilder let deck: Deck

    /// Made once, see `SceneBox`.
    @StateObject private var stageBox = SceneBox(RoundStageScene(
        size: CGSize(width: 390, height: 844),
        reduceMotion: UIAccessibility.isReduceMotionEnabled
    ))
    private var scene: RoundStageScene { stageBox.scene }

    var body: some View {
        GeometryReader { proxy in
            let stageHeight = proxy.size.height * stageShare
            let compact = proxy.size.height < 700
            ZStack(alignment: .top) {
                SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        stage
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        GameRoundButton(symbol: "chevron.backward", label: Strings.Main.back, diameter: 50, action: onBack)
                            .disabled(!canGoBack)
                            .opacity(canGoBack ? 1 : 0.4)
                            .padding(.leading, 16)
                            .padding(.top, 4)
                    }
                    .frame(height: stageHeight)

                    GameDeck {
                        // Scrolls only when it has to: on a short phone a long line or the
                        // result buttons would otherwise push controls off the screen.
                        ScrollView(.vertical) {
                            deck
                                .padding(.horizontal, 16)
                                .padding(.top, compact ? 12 : 16)
                                .padding(.bottom, 12)
                        }
                        .scrollIndicators(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    .environment(\.gameCompactDeck, compact)
                }

                SpriteView(scene: fx, options: [.allowsTransparency, .ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onAppear { syncScene(proxy: proxy, stageHeight: stageHeight) }
            .onChange(of: proxy.size) { _, _ in syncScene(proxy: proxy, stageHeight: stageHeight) }
        }
        .background(Color.gameNavy.ignoresSafeArea())
        .onAppear { scene.set(mood) }
        .onChange(of: mood) { _, mood in scene.set(mood) }
        .hidesNavigationBar()
    }

    /// The scene runs under the status bar, so its stage is the safe top plus the stage area.
    private func syncScene(proxy: GeometryProxy, stageHeight: CGFloat) {
        scene.safeInsets = proxy.safeAreaInsets
        scene.stageHeight = proxy.safeAreaInsets.top + stageHeight
    }
}
