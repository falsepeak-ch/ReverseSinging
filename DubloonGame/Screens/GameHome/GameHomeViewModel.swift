//
//  GameHomeViewModel.swift
//  DubloonGame
//
//  The stage: which games are on it, which one is pushed, and what the host says.
//

import SwiftUI
import Combine
import DubScoring

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
    /// Stars won across every sound, recounted whenever the stage comes back.
    @Published private(set) var starsWon = 0

    private let access: AccessController
    /// The Halloween deal pinned over the stage.
    private let halloween: HalloweenOffer
    private var cancellables = Set<AnyCancellable>()

    init(access: AccessController = .shared, halloween: HalloweenOffer = .shared) {
        self.access = access
        self.halloween = halloween
        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        halloween.objectWillChange
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
        starsWon = Self.countStars()
    }

    /// Three a sound at most, as the round awards them.
    static var maxStars: Int { ImitationSoundLibrary.all.count * 3 }

    static func countStars(store: ImitationProgressStore = .shared) -> Int {
        ImitationSoundLibrary.all.reduce(0) { total, sound in
            total + (store.best(for: sound).map { ScorePart.stars(for: DubGrade.forScore($0)) } ?? 0)
        }
    }

    /// What the SpriteKit stage shows.
    var stageState: StageState {
        StageState(
            hostLine: hostLine,
            proTitle: offersPro ? Strings.Pro.freeTakesTitle(left: freeTakesLeft) : nil,
            isOutOfTakes: offersPro && freeTakesLeft == 0,
            stars: starsWon,
            maxStars: Self.maxStars
        )
    }

    // MARK: - Halloween deal

    /// What the Halloween banner says, while it is shown. See `HalloweenOffer.isShown`.
    var halloweenDeal: HalloweenDeal? { halloween.deal() }

    var isClaimingHalloweenDeal: Bool { halloween.isPurchasing }

    func loadHalloweenDeal() async {
        await halloween.load()
    }

    func claimHalloweenDeal() {
        Task { await halloween.purchase(source: "game_home_halloween_banner") }
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
