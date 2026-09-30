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
    /// The note over the games that offers Dubloon Pro.
    case unlockCard = "unlock_card"
    /// A paid game, tapped while it is padlocked.
    case lockedGame = "locked_game"
    /// A dub pack opened from Files or AirDrop while dubbing is padlocked.
    case lockedImport = "locked_import"

    var id: String { rawValue }
}

/// Drives the menu.
///
/// Owns the navigation path the games are pushed onto, and decides which of the one-off notes,
/// the early-adopter welcome and the Booth Cam announcement, is on screen. Never both at once.
///
/// It is also where Dubloon Pro is enforced: every way into a game asks
/// `canEnter(_:orShowPaywallFrom:)`, which opens the paywall instead of a paid game for someone
/// who has not bought it. Which games are paid is `requiresPro(_:)`, below, and nowhere else.
///
/// And it is where someone who has bought Dubloon Pro, or keeps coming back, is asked how it
/// is going: a rating out of five, which leads to the App Store or to a note for us.
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

    /// The rating last tapped on the review banner, lit on it while its dialog is up. Zero
    /// when nothing is being answered.
    @Published private(set) var reviewStars = 0
    /// A high rating: the offer to write a review on the App Store.
    @Published var isReviewStoreAskPresented = false
    /// A low rating: the dialog that asks what went wrong.
    @Published var isReviewFeedbackPresented = false

    /// Whether anything is locked. Its changes are passed on as this model's own.
    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    /// A pack arrived while the games were disabled. If the paywall it led to ends in a
    /// purchase, the library opens and takes the pack in, as it would have done.
    private var opensDubOnceUnlocked = false

    private let reviewBanner: ReviewBanner
    private let reviewPrompt: ReviewPrompt
    private var hasReportedReviewBannerShown = false

    init(reviewBanner: ReviewBanner = .shared, reviewPrompt: ReviewPrompt = .shared) {
        access = AccessController.shared
        self.reviewBanner = reviewBanner
        self.reviewPrompt = reviewPrompt
        isReviewBannerDue = reviewBanner.isDue()

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        access.$state
            .removeDuplicates()
            .sink { [weak self] state in self?.accessStateDidChange(state) }
            .store(in: &cancellables)
    }

    /// Nothing was bought: the menu says so, and its paid games open the paywall rather than
    /// themselves.
    var areGamesLocked: Bool { access.isLocked }

    /// Whether this game is disabled right now.
    func isLocked(_ mode: GameMode) -> Bool {
        areGamesLocked && requiresPro(mode)
    }

    /// Whether this game stays open while the paid ones are locked, so the menu can say so.
    func isFree(_ mode: GameMode) -> Bool {
        areGamesLocked && !requiresPro(mode)
    }

    /// Which games Dubloon Pro pays for. Reverse singing is how most people meet the app, and
    /// Home Video Dub is played on the user's own video, so there is no content in it to pay
    /// for: both are free for everyone. Dubbing and Sound Imitation are the paid ones.
    private func requiresPro(_ mode: GameMode) -> Bool {
        switch mode {
        case .reverse, .homeVideo: false
        case .dub, .imitate: true
        }
    }

    var shouldWelcomeEarlyAdopter: Bool { access.shouldWelcomeEarlyAdopter }

    /// The note that asks for a rating. Only for someone who has imported a dub pack and used
    /// the app on at least three different days, whether or not they have paid: by then they
    /// know the app well enough for the rating to mean something.
    var showsReviewBanner: Bool { reviewPrompt.isBannerAudience && isReviewBannerDue }

    /// Buyers get thanked for going Pro; everyone else is asked whether they are having fun.
    var reviewBannerThanksForPro: Bool { access.isPro }

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

    /// The one check every way into a game makes. Without Dubloon Pro it answers no for a
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

    /// A subscription that runs out with a paid game open closes the game; the menu is where
    /// the offer is. A free game carries on. Fed the new value rather than reading `access.isLocked`,
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

    /// A star was tapped. Four or five offer the App Store; fewer ask what went wrong.
    func rateFromReviewBanner(stars: Int) {
        reviewStars = stars
        reviewBanner.recordRated(stars: stars)
        switch ReviewBanner.destination(forStars: stars) {
        case .store: isReviewStoreAskPresented = true
        case .feedback: isReviewFeedbackPresented = true
        }
    }

    /// Either dialog was closed without an answer. The banner stays, with its stars cleared,
    /// so the rating can be given again or the note put away with "Not now".
    func reviewDialogDidCancel() {
        isReviewFeedbackPresented = false
        reviewStars = 0
    }

    /// Where "Write a review" goes. The view opens it, so the tap stays a plain link.
    func reviewBannerWentToStore() -> URL {
        reviewBanner.recordWentToStore()
        isReviewBannerDue = false
        reviewStars = 0
        return ReviewBanner.writeReviewURL
    }

    /// Sends the note from the feedback dialog, and the banner is done.
    ///
    /// Returns an email to open instead when the note cannot travel the usual way: with Share
    /// Usage Data off nothing goes to Firebase, and a note someone took the time to write
    /// should not vanish because of a switch that was about statistics. The dialog then stays
    /// up, with the note in it, until `reviewFeedbackMailDidOpen` says Mail took it: a phone
    /// with no mail account would otherwise lose the note and the banner both.
    func sendReviewFeedback(_ message: String) -> URL? {
        let stars = reviewStars
        guard UsageDataConsent.isGranted else {
            let note = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !note.isEmpty else { return nil }
            return AppLinks.supportMail(subject: Strings.Help.mailSubject, details: "\(stars)/\(ReviewBanner.maximumStars)\n\(note)")
        }

        isReviewFeedbackPresented = false
        reviewStars = 0
        if reviewBanner.recordFeedback(stars: stars, message: message) {
            isReviewBannerDue = false
        }
        return nil
    }

    /// Whether Mail opened with the note. If it did, the banner has had its answer.
    func reviewFeedbackMailDidOpen(_ opened: Bool) {
        guard opened else { return }
        reviewBanner.recordFeedbackSentByMail()
        isReviewFeedbackPresented = false
        reviewStars = 0
        isReviewBannerDue = false
    }

    func dismissReviewBanner() {
        reviewBanner.recordDismissed()
        isReviewBannerDue = false
        reviewStars = 0
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
