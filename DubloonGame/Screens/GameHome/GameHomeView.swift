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
    /// The star wipe between the stage and a game: 1 open, 0 closed.
    @State private var iris: CGFloat = 1
    /// The reminders' primer, offered once after the first finished round.
    @State private var isReminderPrimerShown = false
    /// The Halloween plan's terms, shown before the store's sheet. See `HalloweenDealModal`.
    @State private var isHalloweenDealPresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            // The Halloween deal, pinned over the stage. As an inset, the stage reads it as
            // part of the safe area and lays its title out underneath.
            .safeAreaInset(edge: .top, spacing: 0) {
                if let deal = viewModel.halloweenDeal {
                    HalloweenOfferBanner(
                        introPrice: deal.introPrice,
                        renewalPrice: deal.renewalPrice,
                        endDate: deal.endDate,
                        isPurchasing: viewModel.isClaimingHalloweenDeal
                    ) {
                        showHalloweenDeal()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.3), value: viewModel.halloweenDeal != nil)
            .task { await viewModel.loadHalloweenDeal() }
            .background(Color.gameNavy.ignoresSafeArea())
            .accessibilityRepresentation { accessibleStage }
            .hidesNavigationBar()
            .navigationDestination(for: GameMode.self) { mode in
                destination(for: mode)
            }
            .onAppear {
                isStageVisible = true
                viewModel.onAppear()
                #if DEBUG
                if let shot = GameShot.current {
                    if shot.opensScenes, viewModel.path.isEmpty { viewModel.open(.dub) }
                    if shot.opensSounds, viewModel.path.isEmpty { viewModel.open(.imitate) }
                    return
                }
                #endif
                offerRemindersIfDue()
            }
            .onDisappear { isStageVisible = false }
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView(app: app)
        }
        .editorModal(isPresented: $isHalloweenDealPresented) {
            if let deal = viewModel.halloweenDeal {
                HalloweenDealModal(deal: deal) {
                    isHalloweenDealPresented = false
                    viewModel.claimHalloweenDeal()
                } onClose: {
                    isHalloweenDealPresented = false
                }
            }
        }
        .sheet(isPresented: $viewModel.isPaywallPresented) {
            ProPaywallView(source: "game_home")
                .paywallAppearance()
        }
        .overlay {
            if isReminderPrimerShown {
                ReminderPrimerCard {
                    isReminderPrimerShown = false
                    Task { await GameReminders.requestPermission() }
                }
                .transition(.opacity)
            }
        }
        .overlay {
            StarWipe(progress: iris)
                .ignoresSafeArea()
                .allowsHitTesting(iris < 1)
                .accessibilityHidden(true)
        }
        .onAppear(perform: connectScene)
        .onChange(of: viewModel.stageState) { _, state in scene.apply(state) }
        .onChange(of: app.showDubLibrary) { _, wantsLibrary in
            viewModel.dubLibraryRequestDidChange(wantsLibrary, app: app)
        }
    }

    private func connectScene() {
        scene.onSelectGame = { mode in
            Task { await open(mode) }
        }
        scene.onPro = { viewModel.showPaywall() }
        scene.onSettings = { app.showSettings = true }
        scene.onLeaderboards = { GameCenterManager.shared.showLeaderboards() }
        scene.apply(viewModel.stageState)
    }

    /// Back on the stage after the first finished round: a beat for the host to settle, then
    /// the reminders' primer, once.
    private func offerRemindersIfDue() {
        Task {
            guard await GameReminders.shouldOfferPrimer() else { return }
            try? await Task.sleep(for: .seconds(1.2))
            guard viewModel.path.isEmpty, !app.showSettings else { return }
            withAnimation { isReminderPrimerShown = true }
        }
    }

    /// Closes a star over the stage, opens the game under it, and opens the star again.
    private func open(_ mode: GameMode) async {
        guard !reduceMotion else {
            viewModel.open(mode)
            return
        }
        GameSFX.play(.whoosh)
        withAnimation(.easeIn(duration: 0.32)) { iris = 0 }
        try? await Task.sleep(for: .milliseconds(340))
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { viewModel.open(mode) }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.easeOut(duration: 0.45)) { iris = 1 }
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

    private func showHalloweenDeal() {
        GameSFX.play(.tap)
        isHalloweenDealPresented = true
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
            if let deal = viewModel.halloweenDeal {
                Button("\(Strings.HalloweenDeal.badge). \(String(format: Strings.HalloweenDeal.title, deal.introPrice))") {
                    showHalloweenDeal()
                }
            }
            if let proTitle = viewModel.stageState.proTitle {
                Button(proTitle) { viewModel.showPaywall() }
            }
            Button(GameStrings.leaderboards) { GameCenterManager.shared.showLeaderboards() }
            Button(Strings.Settings.title) { app.showSettings = true }
        }
    }
}

/// A navy curtain with a star-shaped hole, as a game show wipes between segments. At 1 the
/// star is wider than the screen; at 0 it has closed to nothing.
private struct StarWipe: View, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let reach = hypot(size.width, size.height) * 1.1
            let radius = reach * max(progress, 0)
            let center = CGPoint(x: size.width / 2, y: size.height * 0.48)
            let star = Self.star(center: center, radius: radius, rotation: (1 - progress) * .pi * 0.6)
            if progress < 1 {
                ZStack {
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: size))
                        path.addPath(star)
                    }
                    .fill(Color.gameNavy, style: FillStyle(eoFill: true))
                    star.stroke(Color.gameGold, lineWidth: 8)
                }
            }
        }
    }

    static func star(center: CGPoint, radius: CGFloat, rotation: CGFloat) -> Path {
        var path = Path()
        guard radius > 0 else { return path }
        for index in 0..<10 {
            let r = index.isMultiple(of: 2) ? radius : radius * 0.48
            let angle = -.pi / 2 + rotation + CGFloat(index) * .pi / 5
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
