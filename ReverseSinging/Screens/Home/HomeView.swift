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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel = HomeViewModel()
    @State private var isHelpPresented = false

    /// The reverse game's model. Held by the menu rather than by the game screen, so a
    /// session in progress survives going back to the menu and in again.
    @StateObject private var game = ReverseGameViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ZStack {
                Color.rsSurface0
                    .ignoresSafeArea()

                menu
                    // Centred on the seam, so the two columns of games keep their gutter on it.
                    .centredOnWindowMiddle(isRegular)

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
                .sheetBesideTheSeam()
        }
        .sheet(item: $viewModel.paywallSource) { source in
            ProPaywallView(source: source.rawValue)
                .paywallAppearance()
                .sheetBesideTheSeam()
        }
        .sheet(isPresented: $viewModel.isEarlyAdopterWelcomePresented) {
            EarlyAdopterWelcomeView()
                .onDisappear { viewModel.earlyAdopterWelcomeDidDisappear() }
                .sheetBesideTheSeam()
        }
        .sheet(isPresented: $viewModel.isBoothAnnouncementPresented) {
            BoothCamAnnouncementView(onTryIt: { viewModel.openDub() })
                .onDisappear { viewModel.boothAnnouncementDidDisappear() }
                .sheetBesideTheSeam()
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
                    if let mail = viewModel.sendReviewFeedback(note) {
                        openURL(mail) { opened in viewModel.reviewFeedbackMailDidOpen(opened) }
                    }
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
        // Again whenever access changes: a subscription that lapses can open a win-back offer.
        .task(id: viewModel.areGamesLocked) { await viewModel.refreshOffer() }
        .onChange(of: app.showDubLibrary) { _, wantsLibrary in
            viewModel.dubLibraryRequestDidChange(wantsLibrary, app: app)
        }
        // Initial too: a link that opened the app cold is waiting before the menu appears.
        .onChange(of: app.pendingDeepLink, initial: true) { _, link in
            guard let link else { return }
            app.pendingDeepLink = nil
            viewModel.open(link)
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

    /// Scrolls, under the header. The four games alone fit any iPhone; with the Pro note or
    /// the review note above them they do not fit a small one, and a menu that cannot be
    /// scrolled pushes its last game, and its own header, off the screen.
    /// iPhone Duo open: both size classes regular, so the menu has room to breathe.
    private var isRegular: Bool {
        sizeClass == .regular && verticalSizeClass == .regular
    }

    private var menu: some View {
        GeometryReader { proxy in
        let fold = horizontalFold(in: proxy)
        ScrollView {
            VStack(spacing: 0) {
            // Half folded as a table: a stage of props on the upper half, the games on the
            // half that rests on the table, so none of them sits on the fold.
            if let fold {
                foldStage
                    .frame(height: max(0, fold.minY))
                    .padding(.bottom, fold.height)
            }
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

                if viewModel.showsSpookyVoiceWeek {
                    SpookyVoiceWeekCard(isLocked: viewModel.isSpookyVoiceWeekLocked) {
                        viewModel.openSpookyVoiceWeek()
                    }
                    .padding(.bottom, 10)
                }

                if let offer = viewModel.visibleOffer {
                    OfferBannerCard(
                        offer: offer,
                        onTap: { viewModel.offerBannerTapped() },
                        onDismiss: { viewModel.dismissOfferBanner() }
                    )
                    .padding(.bottom, 10)
                    .transition(.opacity)
                } else if viewModel.areGamesLocked {
                    UnlockProCard { viewModel.showPaywall(from: .unlockCard) }
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }

                EditorSectionHeader(title: Strings.Main.Mode.section)

                // One column on an iPhone; two on a regular width (iPhone Duo open), so the
                // four games sit two by two with none on the fold.
                LazyVGrid(columns: ReadableColumns.columns(for: sizeClass, spacing: 10, dynamicTypeSize: dynamicTypeSize), spacing: 10) {
                    ForEach(GameMode.allCases) { mode in
                        GameModeRow(
                            mode: mode,
                            isLocked: viewModel.isLocked(mode),
                            isFree: viewModel.isFree(mode),
                            // Large rows only where two of them fit side by side with room
                            // for their text, not in a narrow window that is still regular.
                            prominent: isRegular && proxy.size.width >= 740
                        ) {
                            viewModel.open(mode)
                        }
                    }
                }
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .animation(.rsQuick, value: viewModel.areGamesLocked)
            .animation(.rsQuick, value: viewModel.visibleOffer)
            .animation(.rsQuick, value: viewModel.showsReviewBanner)
            // On a regular size the games sit in the middle of the screen rather than
            // in a strip along its top; on an iPhone they stay top-aligned.
            .frame(minHeight: fold.map { proxy.size.height - $0.maxY } ?? (isRegular ? proxy.size.height : nil), alignment: .center)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, EditorMetrics.headerBarHeight)
    }

    // MARK: - Fold

    /// The fold, in the menu's space, while it runs across the screen (iPhone Duo half
    /// folded as a table) with room on both sides; nil otherwise.
    private func horizontalFold(in proxy: GeometryProxy) -> CGRect? {
        guard !dynamicTypeSize.isAccessibilitySize, let fold = proxy.horizontalFold,
              fold.minY > 160, fold.maxY < proxy.size.height - 160
        else { return nil }
        return fold
    }

    /// The studio's props, lined up like a shelf: decoration only.
    private var foldStage: some View {
        HStack(alignment: .bottom, spacing: 20) {
            Image("headphones").resizable().scaledToFit().frame(width: 92)
            Image("film-reel").resizable().scaledToFit().frame(width: 104)
            Image("microphone").resizable().scaledToFit().frame(width: 150)
            Image("clapperboard").resizable().scaledToFit().frame(width: 104)
            Image("radio").resizable().scaledToFit().frame(width: 92)
        }
        .padding(.horizontal, EditorMetrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    // MARK: - Header

    /// iPhone Duo open: Help and Settings are bar items, the same square buttons, so they sit
    /// in the bar the inner display draws (the trailing strip in landscape), not the content.
    private var usesSystemBar: Bool {
        EditorBars.useSystemBar(sizeClass, verticalSizeClass)
    }

    private var header: some View {
        VStack(spacing: 0) {
            EditorHeaderBar {
                Image("icon-lettering")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)

                Spacer()

                if !usesSystemBar {
                    HelpButton(topic: .gettingStarted)

                    settingsButton
                }
            }

            Spacer()
        }
        #if os(iOS)
        .toolbar {
            if usesSystemBar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditorToolbarButton(icon: "questionmark", label: Strings.Help.title) {
                        isHelpPresented = true
                    }

                    settingsButton
                }
                .editorChromeItems()
            }
        }
        .sheet(isPresented: $isHelpPresented) {
            HelpView(topic: .gettingStarted)
                .sheetBesideTheSeam()
                .presentationDragIndicator(.visible)
        }
        #endif
    }

    private var settingsButton: some View {
        EditorToolbarButton(
            icon: "slider.horizontal.3",
            label: Strings.Settings.title
        ) {
            app.showSettings = true
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
        .preferredColorScheme(.dark)
}
