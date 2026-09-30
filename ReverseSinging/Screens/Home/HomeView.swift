//
//  HomeView.swift
//  ReverseSinging
//
//  The menu: pick a game, push into it.
//

import SwiftUI

/// The root screen. It plays nothing itself. It lists the games and owns the
/// navigation stack they are pushed onto, so each game is a level deeper rather
/// than something hidden behind a toolbar glyph.
struct HomeView: View {
    @EnvironmentObject var app: AppViewModel
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = HomeViewModel()

    /// The reverse game's model. Held by the menu rather than by the game screen, so a
    /// session in progress survives going back to the menu and in again.
    @StateObject private var game = ReverseGameViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ZStack {
                Color.rsSurface0
                    .ignoresSafeArea()

                menu

                header
            }
            .hidesNavigationBar()
            .navigationDestination(for: GameMode.self) { mode in
                destination(for: mode)
            }
            // Backing out of a game rewinds it: see `RewindTransition`.
            .rewindNavigationTransition()
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView(app: app)
        }
        .sheet(item: $viewModel.paywallSource) { source in
            ProPaywallView(source: source.rawValue)
                .paywallAppearance()
        }
        .sheet(isPresented: $viewModel.isEarlyAdopterWelcomePresented) {
            EarlyAdopterWelcomeView()
                .onDisappear { viewModel.earlyAdopterWelcomeDidDisappear() }
        }
        .sheet(isPresented: $viewModel.isBoothAnnouncementPresented) {
            BoothCamAnnouncementView(onTryIt: { viewModel.openDub() })
                .onDisappear { viewModel.boothAnnouncementDidDisappear() }
        }
        .alert(Strings.ReviewBanner.storeTitle, isPresented: $viewModel.isReviewStoreAskPresented) {
            Button(Strings.ReviewBanner.rate) { openURL(viewModel.reviewBannerWentToStore()) }
            Button(Strings.Main.Alert.cancel, role: .cancel) { viewModel.reviewDialogDidCancel() }
        } message: {
            Text(viewModel.reviewBannerThanksForPro ? Strings.ReviewBanner.message : Strings.ReviewBanner.fanMessage)
        }
        .editorModal(isPresented: $viewModel.isReviewFeedbackPresented) {
            ReviewFeedbackModal(
                stars: viewModel.reviewStars,
                onSend: { note in
                    if let mail = viewModel.sendReviewFeedback(note) { openURL(mail) }
                },
                onCancel: { viewModel.reviewDialogDidCancel() }
            )
        }
        // Watched rather than checked once on appear: the exemption can be granted
        // a beat after launch, when the receipt lands, and this is the menu the
        // user is already looking at when it does.
        .onChange(of: viewModel.shouldWelcomeEarlyAdopter, initial: true) { _, _ in
            viewModel.presentEarlyAdopterWelcomeIfDue()
        }
        .onAppear { viewModel.onAppear(game: game, app: app) }
        .onChange(of: app.showDubLibrary) { _, wantsLibrary in
            viewModel.dubLibraryRequestDidChange(wantsLibrary, app: app)
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for mode: GameMode) -> some View {
        switch mode {
        case .reverse:
            // The interface preference chooses how reverse singing looks. It is a
            // setting on this one game, not a separate game.
            if app.uiMode == .simple {
                MainViewSimple()
                    .environmentObject(game)
            } else {
                MainViewPremium()
                    .environmentObject(game)
            }
        case .dub:
            DubLibraryView(pendingImportURL: $app.pendingDubImportURL, isPushed: true)
        case .homeVideo:
            HomeVideoDubView()
        case .imitate:
            SoundLibraryView()
        }
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: EditorMetrics.headerBarHeight)

            VStack(alignment: .leading, spacing: 10) {
                if viewModel.showsReviewBanner {
                    ReviewBannerCard(
                        thanksForPro: viewModel.reviewBannerThanksForPro,
                        stars: viewModel.reviewStars,
                        onRate: { viewModel.rateFromReviewBanner(stars: $0) },
                        onDismiss: { viewModel.dismissReviewBanner() }
                    )
                    .padding(.bottom, 10)
                    .transition(.opacity)
                    .onAppear { viewModel.reviewBannerDidAppear() }
                }

                if viewModel.areGamesLocked {
                    TrialEndedCard(title: viewModel.lockedCardTitle) { viewModel.showPaywall(from: .trialEndedCard) }
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }

                EditorSectionHeader(title: Strings.Main.Mode.section)

                ForEach(GameMode.allCases) { mode in
                    GameModeRow(
                        mode: mode,
                        isLocked: viewModel.isLocked(mode),
                        isFree: viewModel.isFree(mode)
                    ) {
                        viewModel.open(mode)
                    }
                }
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.top, 20)
            .animation(.rsQuick, value: viewModel.areGamesLocked)
            .animation(.rsQuick, value: viewModel.showsReviewBanner)

            Spacer()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            EditorHeaderBar {
                Image("icon-lettering")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)

                Spacer()

                if let daysRemaining = viewModel.trialDaysRemaining {
                    TrialBadge(daysRemaining: daysRemaining) {
                        viewModel.showPaywall(from: .trialBadge)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                HelpButton(topic: .gettingStarted)

                EditorToolbarButton(
                    icon: "slider.horizontal.3",
                    label: Strings.Settings.title
                ) {
                    app.showSettings = true
                }
            }

            Spacer()
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
        .preferredColorScheme(.dark)
}
