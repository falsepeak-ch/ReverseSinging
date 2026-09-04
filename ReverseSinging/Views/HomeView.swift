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
    @EnvironmentObject var viewModel: AudioViewModel
    @State private var path: [GameMode] = []

    /// The counter lives here because this is the screen every session starts on,
    /// and it is the only place in the app that mentions the trial unprompted.
    @ObservedObject private var access = AccessController.shared
    @State private var isPaywallPresented = false
    @State private var isEarlyAdopterWelcomePresented = false

    var body: some View {
        NavigationStack(path: $path) {
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
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $isPaywallPresented) {
            ProPaywallView(source: "trial_badge")
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $isEarlyAdopterWelcomePresented) {
            EarlyAdopterWelcomeView()
                .preferredColorScheme(.dark)
                // Marked on the way out rather than on the way in, so a user who
                // kills the app mid-animation still gets told.
                .onDisappear { access.markEarlyAdopterWelcomed() }
        }
        // Watched rather than checked once on appear: the exemption can be granted
        // a beat after launch, when the receipt lands, and this is the menu the
        // user is already looking at when it does.
        .onChange(of: access.shouldWelcomeEarlyAdopter, initial: true) { _, shouldWelcome in
            guard shouldWelcome, !isEarlyAdopterWelcomePresented else { return }
            #if DEBUG
            if ScreenshotMode.isActive { return }
            #endif
            isEarlyAdopterWelcomePresented = true
            AnalyticsManager.shared.trackEarlyAdopterWelcomeShown()
        }
        .onAppear {
            viewModel.checkPermissionStatus()
            AnalyticsManager.shared.trackScreenViewed(screenName: "Home")
            #if DEBUG
            applyScreenshotDestination()
            #endif
        }
        // A dub pack arriving from Files or AirDrop opens the library the same way
        // a tap would, so imports land on a screen the user can navigate back from.
        .onChange(of: viewModel.showDubLibrary) { _, wantsLibrary in
            guard wantsLibrary else { return }
            viewModel.showDubLibrary = false
            // Reset rather than append: an import should land on the library itself,
            // not stacked on top of whatever game was open.
            path = [.dub]
        }
    }

    // MARK: - Screenshots

    #if DEBUG
    /// Pushes the game the capture script asked for, so every screen below the menu
    /// is reachable from a cold launch without anything having to tap.
    private func applyScreenshotDestination() {
        guard ScreenshotMode.isActive, let destination = ScreenshotMode.destination else { return }

        if destination.opensDubGame {
            path = [.dub]
        } else if destination.opensReverseGame {
            ScreenshotMode.seedReverseSession(into: &viewModel.appState)
            path = [.reverse]
        } else if destination.opensSettings {
            viewModel.showSettings = true
        }
    }
    #endif

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for mode: GameMode) -> some View {
        switch mode {
        case .reverse:
            // The interface preference chooses how reverse singing looks. It is a
            // setting on this one game, not a separate game.
            if viewModel.appState.uiMode == .simple {
                MainViewSimple()
                    .environmentObject(viewModel)
            } else {
                MainViewPremium()
                    .environmentObject(viewModel)
            }
        case .dub:
            DubLibraryView(pendingImportURL: $viewModel.pendingDubImportURL, isPushed: true)
        }
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 96)

            VStack(alignment: .leading, spacing: 10) {
                EditorSectionHeader(title: Strings.Main.Mode.section)

                ForEach(GameMode.allCases) { mode in
                    GameModeRow(mode: mode) { path.append(mode) }
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
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Image("icon-lettering")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)

                    Spacer()

                    if let daysRemaining = access.trialDaysRemaining {
                        TrialBadge(daysRemaining: daysRemaining) {
                            isPaywallPresented = true
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    EditorToolbarButton(
                        icon: "slider.horizontal.3",
                        label: Strings.Settings.title
                    ) {
                        viewModel.showSettings = true
                    }
                }
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.bottom, 10)
            }
            .frame(height: 96)
            .background(Color.rsSurface1)
            .overlay(alignment: .bottom) { EditorRule() }

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }
}

#Preview {
    HomeView()
        .environmentObject(AudioViewModel())
        .preferredColorScheme(.dark)
}
