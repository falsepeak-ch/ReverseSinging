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
    /// A game that is disabled because the trial is over.
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
/// into a game asks `canEnterGames(orShowPaywallFrom:)`, which opens the paywall instead once
/// the trial is over.
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

    /// The trial counter lives on the menu because this is the screen every session starts on,
    /// and it is the only place in the app that mentions the trial unprompted. Its changes are
    /// passed on as this model's own.
    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    /// A pack arrived while the games were disabled. If the paywall it led to ends in a
    /// purchase, the library opens and takes the pack in, as it would have done.
    private var opensDubOnceUnlocked = false

    init() {
        access = AccessController.shared

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        access.$state
            .removeDuplicates()
            .sink { [weak self] state in self?.accessStateDidChange(state) }
            .store(in: &cancellables)
    }

    var trialDaysRemaining: Int? { access.trialDaysRemaining }

    /// The trial is over and nothing was bought: the menu says so, and its games open the
    /// paywall rather than themselves.
    var areGamesLocked: Bool { access.isLocked }

    var shouldWelcomeEarlyAdopter: Bool { access.shouldWelcomeEarlyAdopter }

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
        guard canEnterGames(orShowPaywallFrom: .lockedGame) else { return }
        path.append(mode)
    }

    func openDub() {
        guard canEnterGames(orShowPaywallFrom: .lockedGame) else { return }
        path = [.dub]
    }

    /// The one check every way into a game makes. While the trial is over it answers no and
    /// opens the paywall, so a disabled game still does something when tapped.
    private func canEnterGames(orShowPaywallFrom source: HomePaywallSource) -> Bool {
        guard areGamesLocked else { return true }
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
        guard canEnterGames(orShowPaywallFrom: .lockedImport) else {
            opensDubOnceUnlocked = true
            return
        }
        // Reset rather than append: an import should land on the library itself,
        // not stacked on top of whatever game was open.
        path = [.dub]
    }

    /// A trial that runs out with a game open closes the game; the menu is where the offer is.
    /// Fed the new value rather than reading `access`, which has not changed yet when a
    /// `@Published` sink fires.
    private func accessStateDidChange(_ state: AccessState) {
        if state == .locked {
            path = []
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
