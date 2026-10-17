//
//  GameHomeView.swift
//  DubloonGame
//
//  The home stage: the SpriteKit scene, and the games pushed from it.
//

import SwiftUI
import SpriteKit

/// The root screen. The stage is a SpriteKit scene; the games are the shared SwiftUI screens,
/// pushed onto the navigation stack this view owns.
struct GameHomeView: View {
    @EnvironmentObject var app: AppViewModel
    @StateObject private var viewModel = GameHomeViewModel()

    /// Made once, see `SceneBox`.
    @StateObject private var stage = SceneBox(GameStageScene(
        size: CGSize(width: 390, height: 844),
        reduceMotion: UIAccessibility.isReduceMotionEnabled
    ))
    private var scene: GameStageScene { stage.scene }
    /// The stage stops rendering while a game is on top of it.
    @State private var isStageVisible = true

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            GeometryReader { proxy in
                SpriteView(
                    scene: scene,
                    isPaused: !isStageVisible,
                    preferredFramesPerSecond: 60,
                    options: [.ignoresSiblingOrder]
                )
                .ignoresSafeArea()
                .onAppear { scene.safeInsets = proxy.safeAreaInsets }
                .onChange(of: proxy.safeAreaInsets) { _, insets in scene.safeInsets = insets }
            }
            .background(Color.gameNavy.ignoresSafeArea())
            .accessibilityRepresentation { accessibleStage }
            .hidesNavigationBar()
            .navigationDestination(for: GameMode.self) { mode in
                destination(for: mode)
            }
            .onAppear {
                isStageVisible = true
                viewModel.onAppear()
            }
            .onDisappear { isStageVisible = false }
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView(app: app)
        }
        .sheet(isPresented: $viewModel.isPaywallPresented) {
            ProPaywallView(source: "game_home")
                .paywallAppearance()
        }
        .onAppear(perform: connectScene)
        .onChange(of: viewModel.stageState) { _, state in scene.apply(state) }
        .onChange(of: app.showDubLibrary) { _, wantsLibrary in
            viewModel.dubLibraryRequestDidChange(wantsLibrary, app: app)
        }
    }

    private func connectScene() {
        scene.onSelectGame = { mode in viewModel.open(mode) }
        scene.onPro = { viewModel.showPaywall() }
        scene.onSettings = { app.showSettings = true }
        scene.apply(viewModel.stageState)
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for mode: GameMode) -> some View {
        switch mode {
        case .dub:
            GameScenePickerView(pendingImportURL: $app.pendingDubImportURL)
        case .imitate:
            GameSoundPickerView()
        case .reverse, .homeVideo:
            // Not in this app.
            EmptyView()
        }
    }

    // MARK: - Accessibility

    /// What VoiceOver and Switch Control get in place of the sprites: the host's line and
    /// the same buttons, in reading order.
    private var accessibleStage: some View {
        VStack {
            Text(viewModel.hostLine)
            ForEach(GameHomeViewModel.games) { mode in
                Button("\(mode.title). \(mode.subtitle)") { viewModel.open(mode) }
            }
            if let proTitle = viewModel.stageState.proTitle {
                Button(proTitle) { viewModel.showPaywall() }
            }
            Button(Strings.Settings.title) { app.showSettings = true }
        }
    }
}
