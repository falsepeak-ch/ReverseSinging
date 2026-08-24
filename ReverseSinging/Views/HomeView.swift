//
//  HomeView.swift
//  ReverseSinging
//
//  The menu: pick a game, push into it.
//

import SwiftUI

/// The root screen. It plays nothing itself — it lists the two games and owns the
/// navigation stack they are pushed onto, so each game is a level deeper rather
/// than something hidden behind a toolbar glyph.
struct HomeView: View {
    @EnvironmentObject var viewModel: AudioViewModel
    @State private var path: [GameMode] = []

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
            // The interface preference chooses how reverse singing looks — it is a
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
