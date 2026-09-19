//
//  HomeViewModel.swift
//  ReverseSinging
//
//  The menu: which game is pushed, and which one-off note is shown on the way in
//

import SwiftUI
import Combine

/// Drives the menu.
///
/// Owns the navigation path the games are pushed onto, and decides which of the one-off notes,
/// the early-adopter welcome and the Booth Cam announcement, is on screen. Never both at once.
@MainActor
final class HomeViewModel: ObservableObject {

    @Published var path: [GameMode] = []

    @Published var isPaywallPresented = false
    @Published var isEarlyAdopterWelcomePresented = false
    /// The Booth Cam note for people who updated, see `BoothCamAnnouncement`.
    @Published var isBoothAnnouncementPresented = false

    /// The trial counter lives on the menu because this is the screen every session starts on,
    /// and it is the only place in the app that mentions the trial unprompted. Its changes are
    /// passed on as this model's own.
    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    init() {
        access = AccessController.shared

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var trialDaysRemaining: Int? { access.trialDaysRemaining }

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
        path.append(mode)
    }

    func openDub() {
        path = [.dub]
    }

    func showPaywall() {
        isPaywallPresented = true
    }

    /// A dub pack arriving from Files or AirDrop opens the library the same way a tap would,
    /// so imports land on a screen the user can navigate back from.
    func dubLibraryRequestDidChange(_ wantsLibrary: Bool, app: AppViewModel) {
        guard wantsLibrary else { return }
        app.showDubLibrary = false
        // Reset rather than append: an import should land on the library itself,
        // not stacked on top of whatever game was open.
        path = [.dub]
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
        guard BoothCamAnnouncement.shared.isDue,
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
