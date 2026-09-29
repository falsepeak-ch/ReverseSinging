//
//  HomeViewModel.swift
//  ReverseSinging
//
//  The menu: which game is pushed, and which one-off note is shown on the way in
//

import SwiftUI
import Combine

/// What opened the menu's paywall, for analytics. Not shown.
enum HomePaywallSource: String, Identifiable {
    /// The days-left counter in the header.
    case trialBadge = "trial_badge"
    /// The note that says the trial is over.
    case trialEndedCard = "trial_ended_card"
    /// A paid game that is disabled because the trial is over.
    case lockedGame = "locked_game"
    /// A dub pack opened from Files or AirDrop while the games are disabled.
    case lockedImport = "locked_import"

    var id: String { rawValue }
}

/// Drives the menu.
///
/// Owns the navigation path the games are pushed onto, and decides which of the one-off notes,
/// the early-adopter welcome and the Booth Cam announcement, is on screen. Never both at once.
///
/// It is also where a closed free window is enforced when the hard paywall is off: every way
/// into a game asks `canEnter(_:orShowPaywallFrom:)`, which opens the paywall instead once the
/// trial is over. Reverse singing is free unless the console says otherwise, so only dubbing
/// is ever locked by default.
///
/// And once someone has bought Dubloon Pro, it is where they are asked for a review.
@MainActor
final class HomeViewModel: ObservableObject {

    @Published var path: [GameMode] = []

    /// The paywall, and what asked for it. Nil while it is closed.
    @Published var paywallSource: HomePaywallSource? {
        didSet {
            // Closed without buying: the pack that led here no longer opens anything later.
            if paywallSource == nil { opensDubOnceUnlocked = false }
        }
    }
    @Published var isEarlyAdopterWelcomePresented = false
    /// The Booth Cam note for people who updated, see `BoothCamAnnouncement`.
    @Published var isBoothAnnouncementPresented = false

    /// Mirrors `ReviewBanner.isDue`, which is not observable, so answering it hides the banner.
    @Published private var isReviewBannerDue: Bool

    /// The trial counter lives on the menu because this is the screen every session starts on,
    /// and it is the only place in the app that mentions the trial unprompted. Its changes are
    /// passed on as this model's own.
    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    /// A pack arrived while the games were disabled. If the paywall it led to ends in a
    /// purchase, the library opens and takes the pack in, as it would have done.
    private var opensDubOnceUnlocked = false

    private let reviewBanner: ReviewBanner
    private var hasReportedReviewBannerShown = false

    init(reviewBanner: ReviewBanner = .shared) {
        access = AccessController.shared
        self.reviewBanner = reviewBanner
        isReviewBannerDue = reviewBanner.isDue()

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        access.$state
            .removeDuplicates()
            .sink { [weak self] state in self?.accessStateDidChange(state) }
            .store(in: &cancellables)
    }

    var trialDaysRemaining: Int? { access.trialDaysRemaining }

    /// The trial is over and nothing was bought: the menu says so, and its paid games open the
    /// paywall rather than themselves.
    var areGamesLocked: Bool { access.isLocked }

    /// Whether this game is disabled right now.
    func isLocked(_ mode: GameMode) -> Bool {
        areGamesLocked && requiresPro(mode)
    }

    /// Whether this game stays open while the paid ones are locked, so the menu can say so.
    func isFree(_ mode: GameMode) -> Bool {
        areGamesLocked && !requiresPro(mode)
    }

    private func requiresPro(_ mode: GameMode) -> Bool {
        switch mode {
        case .reverse: !access.isReverseGameFree
        case .dub: true
        // Free for everyone: the user brings the video, so there is no content to pay for.
        case .homeVideo: false
        case .imitate: !access.isSoundImitationFree
        }
    }

    /// The locked card's headline. Saying a trial ended is only true if there was one: with
    /// the console's trial length at zero, the lock is there from the first launch.
    var lockedCardTitle: String {
        access.hasTrial ? Strings.Pro.Trial.over : Strings.Pro.lockedTitle
    }

    var shouldWelcomeEarlyAdopter: Bool { access.shouldWelcomeEarlyAdopter }

    /// The thank-you note that asks for a review. Only for people who paid: an early adopter
    /// got the app for nothing, and asking someone mid-trial is asking before they have decided.
    var showsReviewBanner: Bool { access.isPro && isReviewBannerDue }

    // MARK: - Screen

    func onAppear(game: ReverseGameViewModel, app: AppViewModel) {
        game.checkPermissionStatus()
        AnalyticsManager.shared.trackScreenViewed(screenName: "Home")
        presentBoothAnnouncementIfDue()
        #if DEBUG
        applyScreenshotDestination(game: game, app: app)
        #endif
    }

    // MARK: - Navigation

    func open(_ mode: GameMode) {
        guard canEnter(mode, orShowPaywallFrom: .lockedGame) else { return }
        path.append(mode)
    }

    func openDub() {
        guard canEnter(.dub, orShowPaywallFrom: .lockedGame) else { return }
        path = [.dub]
    }

    /// For a shell that selects games rather than pushing them, the Mac's sidebar: the same
    /// check, with the paywall opened in place of the game when it answers no.
    func requestEntry(_ mode: GameMode) -> Bool {
        canEnter(mode, orShowPaywallFrom: .lockedGame)
    }

    /// The one check every way into a game makes. While the trial is over it answers no for a
    /// paid game and opens the paywall, so a disabled game still does something when tapped.
    private func canEnter(_ mode: GameMode, orShowPaywallFrom source: HomePaywallSource) -> Bool {
        guard isLocked(mode) else { return true }
        showPaywall(from: source)
        return false
    }

    func showPaywall(from source: HomePaywallSource) {
        paywallSource = source
    }

    /// A dub pack arriving from Files or AirDrop opens the library the same way a tap would,
    /// so imports land on a screen the user can navigate back from.
    func dubLibraryRequestDidChange(_ wantsLibrary: Bool, app: AppViewModel) {
        guard wantsLibrary else { return }
        app.showDubLibrary = false
        // The pack stays pending on `app` either way: the library takes it in whenever it
        // next opens.
        guard canEnter(.dub, orShowPaywallFrom: .lockedImport) else {
            opensDubOnceUnlocked = true
            return
        }
        // Reset rather than append: an import should land on the library itself,
        // not stacked on top of whatever game was open.
        path = [.dub]
    }

    /// A trial that runs out with a paid game open closes the game; the menu is where the offer
    /// is. A free game carries on. Fed the new value rather than reading `access.isLocked`,
    /// which has not changed yet when a `@Published` sink fires.
    private func accessStateDidChange(_ state: AccessState) {
        if state == .locked {
            if path.contains(where: requiresPro) { path = [] }
        } else if opensDubOnceUnlocked {
            opensDubOnceUnlocked = false
            path = [.dub]
        }
    }

    // MARK: - Notes

    func presentEarlyAdopterWelcomeIfDue() {
        guard access.shouldWelcomeEarlyAdopter,
              !isEarlyAdopterWelcomePresented,
              !isBoothAnnouncementPresented else { return }
        #if DEBUG
        if ScreenshotMode.isActive { return }
        #endif
        isEarlyAdopterWelcomePresented = true
    }

    func presentBoothAnnouncementIfDue() {
        // Not while the games are disabled: a note whose button leads to a paywall is an ad.
        // It is not marked shown either, so it is still due once they are back in.
        guard BoothCamAnnouncement.shared.isDue,
              !areGamesLocked,
              !isBoothAnnouncementPresented,
              !isEarlyAdopterWelcomePresented,
              !access.shouldWelcomeEarlyAdopter else { return }
        #if DEBUG
        if ScreenshotMode.isActive { return }
        #endif
        isBoothAnnouncementPresented = true
        AnalyticsManager.shared.trackCustomEvent(name: "booth_announcement_shown", parameters: nil)
    }

    /// Marked on the way out rather than on the way in, so a user who kills the app
    /// mid-animation still gets told.
    func earlyAdopterWelcomeDidDisappear() {
        access.markEarlyAdopterWelcomed()
        // Two notes on one launch happen to whoever skipped 1.4. The gift first, then the
        // feature, never both at once.
        presentBoothAnnouncementIfDue()
    }

    func boothAnnouncementDidDisappear() {
        BoothCamAnnouncement.shared.markShown()
        presentEarlyAdopterWelcomeIfDue()
    }

    // MARK: - Review banner

    /// Counted once per menu, not once per redraw.
    func reviewBannerDidAppear() {
        guard !hasReportedReviewBannerShown else { return }
        hasReportedReviewBannerShown = true
        reviewBanner.recordShown()
    }

    /// Where "Write a review" goes. The view opens it, so the tap stays a plain link.
    func reviewBannerWentToStore() -> URL {
        reviewBanner.recordWentToStore()
        isReviewBannerDue = false
        return ReviewBanner.writeReviewURL
    }

    func dismissReviewBanner() {
        reviewBanner.recordDismissed()
        isReviewBannerDue = false
    }

    // MARK: - Screenshots

    #if DEBUG
    /// Pushes the game the capture script asked for, so every screen below the menu
    /// is reachable from a cold launch without anything having to tap.
    private func applyScreenshotDestination(game: ReverseGameViewModel, app: AppViewModel) {
        guard ScreenshotMode.isActive, let destination = ScreenshotMode.destination else { return }

        if destination.opensDubGame {
            path = [.dub]
        } else if destination.opensReverseGame {
            ScreenshotMode.seedReverseSession(into: &game.appState)
            path = [.reverse]
        } else if destination.opensSettings {
            app.showSettings = true
        }
    }
    #endif
}
