//
//  HomeView.swift
//  ReverseSinging
//
//  The menu: pick a game, push into it.
//

import SwiftUI

/// The root screen. It plays nothing itself. It lists the two games and owns the
/// navigation stack they are pushed onto, so each game is a level deeper rather
/// than something hidden behind a toolbar glyph.
struct HomeView: View {
    @EnvironmentObject var app: AppViewModel
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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: GameMode.self) { mode in
                destination(for: mode)
            }
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView(app: app)
        }
        .sheet(isPresented: $viewModel.isPaywallPresented) {
            ProPaywallView(source: "trial_badge")
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $viewModel.isEarlyAdopterWelcomePresented) {
            EarlyAdopterWelcomeView()
                .preferredColorScheme(.dark)
                .onDisappear { viewModel.earlyAdopterWelcomeDidDisappear() }
        }
        .sheet(isPresented: $viewModel.isBoothAnnouncementPresented) {
            BoothCamAnnouncementView(onTryIt: { viewModel.openDub() })
                .preferredColorScheme(.dark)
                .onDisappear { viewModel.boothAnnouncementDidDisappear() }
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
        }
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: EditorMetrics.headerBarHeight)

            VStack(alignment: .leading, spacing: 10) {
                EditorSectionHeader(title: Strings.Main.Mode.section)

                ForEach(GameMode.allCases) { mode in
                    GameModeRow(mode: mode) { viewModel.open(mode) }
                }
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.top, 20)

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
                        viewModel.showPaywall()
                    }
                    .transition(.scale.combined(with: .opacity))
                }

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
