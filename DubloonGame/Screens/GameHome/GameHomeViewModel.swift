//
//  GameHomeViewModel.swift
//  DubloonGame
//
//  The stage: which games are on it, which one is pushed, and what the host says.
//

import SwiftUI
import Combine

/// Drives the game's home stage.
///
/// The game ships two of Dubloon's games, movie scene dub and sound imitation, on the same
/// terms as the iPhone app: every game opens, the free takes are shared across them
/// (`FreeTakes`), and Dubloon Pro is asked for in a game once they run out.
@MainActor
final class GameHomeViewModel: ObservableObject {

    /// The games on the stage, in order.
    static let games: [GameMode] = [.dub, .imitate]

    @Published var path: [GameMode] = []
    @Published var isPaywallPresented = false

    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    init(access: AccessController = .shared) {
        self.access = access
        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Nothing was bought: the stage offers Dubloon Pro and counts the free takes left.
    var offersPro: Bool { access.isLocked }
    var freeTakesLeft: Int { access.freeTakesLeft }

    var hostLine: String {
        offersPro && freeTakesLeft == 0 ? GameStrings.Host.outOfTakes : GameStrings.Host.greeting
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "GameHome")
    }

    /// What the SpriteKit stage shows.
    var stageState: StageState {
        StageState(
            hostLine: hostLine,
            proTitle: offersPro ? Strings.Pro.freeTakesTitle(left: freeTakesLeft) : nil
        )
    }

    // MARK: - Navigation

    /// The stage has finished its cheer; the game opens.
    func open(_ mode: GameMode) {
        path.append(mode)
    }

    func showPaywall() {
        isPaywallPresented = true
    }

    /// A dub pack arriving from Files or AirDrop lands on the dub library.
    func dubLibraryRequestDidChange(_ wantsLibrary: Bool, app: AppViewModel) {
        guard wantsLibrary else { return }
        app.showDubLibrary = false
        path = [.dub]
    }
}
