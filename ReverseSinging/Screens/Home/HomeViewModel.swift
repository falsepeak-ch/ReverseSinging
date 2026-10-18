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
    /// The subscription offer banner, for an introductory offer.
    case offerBanner = "offer_banner"

    var id: String { rawValue }
}

/// Drives the menu.
///
/// Owns the navigation path the games are pushed onto, and decides when the one-off Booth Cam
/// announcement is on screen.
///
/// Every game opens for everyone. Dubloon Pro is asked for inside the games, once the free
/// takes are used up (`FreeTakes`); the menu only offers it and says how many takes are left.
///
/// And it is where someone who has bought Dubloon Pro, or keeps coming back, is asked how it
/// is going: a rating out of five, which leads to the App Store or to a note for us.
@MainActor
final class HomeViewModel: ObservableObject {

    @Published var path: [GameMode] = []

    /// The paywall, and what asked for it. Nil while it is closed.
    @Published var paywallSource: HomePaywallSource?
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

    /// Whether Pro is owned, and how many free takes are left. Its changes are passed on as
    /// this model's own.
    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    /// The introductory or win-back offer shown over the games, when there is one.
    let offerBanner: SubscriptionOfferBanner

    private let reviewBanner: ReviewBanner
    private let reviewPrompt: ReviewPrompt
    private var hasReportedReviewBannerShown = false

    init(reviewBanner: ReviewBanner = .shared, reviewPrompt: ReviewPrompt = .shared) {
        access = AccessController.shared
        offerBanner = SubscriptionOfferBanner.shared
        self.reviewBanner = reviewBanner
        self.reviewPrompt = reviewPrompt
        isReviewBannerDue = reviewBanner.isDue()

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        offerBanner.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Nothing was bought: the menu offers Dubloon Pro and counts the free takes left.
    var offersPro: Bool { access.isLocked }

    /// Free takes left, across every game.
    var freeTakesLeft: Int { access.freeTakesLeft }

    // MARK: - Offer banner

    /// The offer to put over the games instead of the plain unlock card. Never for someone who
    /// has the app: an active subscriber is not offered anything.
    var visibleOffer: SubscriptionOffer? {
        guard offersPro, offerBanner.isVisible else { return nil }
        return offerBanner.offer
    }

    func refreshOffer() async {
        await offerBanner.refresh(access: access)
        if let offer = visibleOffer {
            AnalyticsManager.shared.trackOfferBanner("shown", kind: offer.kind.rawValue, productID: offer.productID)
        }
    }

    /// An introductory offer opens the paywall, which shows it; a win-back offer goes straight
    /// to the App Store's purchase sheet with the offer applied.
    func offerBannerTapped() {
        guard let offer = visibleOffer else { return }
        AnalyticsManager.shared.trackOfferBanner("tapped", kind: offer.kind.rawValue, productID: offer.productID)
        switch offer.kind {
        case .intro:
            showPaywall(from: .offerBanner)
        case .winBack:
            Task {
                if await !offerBanner.redeemWinBack(access: access) {
                    showPaywall(from: .offerBanner)
                }
            }
        }
    }

    func dismissOfferBanner() {
        if let offer = visibleOffer {
            AnalyticsManager.shared.trackOfferBanner("dismissed", kind: offer.kind.rawValue)
        }
        offerBanner.dismiss()
    }

    /// The Halloween card. Read once per menu: a menu left open past midnight on the 1st of
    /// November keeps it until the next launch, which is better than a card vanishing under a
    /// finger.
    let showsSpookyVoiceWeek = SpookyVoiceWeek.isActiveNow

    /// The note that asks for a rating. Only for someone who has imported a dub pack or had a
    /// few wins, and used the app on at least two different days, whether or not they have
    /// paid: by then they know the app well enough for the rating to mean something.
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
        path.append(mode)
    }

    func openDub() {
        path = [.dub]
    }

    /// The Spooky Voice Week card: the same place `dubloon://event/spooky` goes.
    func openSpookyVoiceWeek() {
        AnalyticsManager.shared.trackCustomEvent(name: "spooky_card_tapped", parameters: nil)
        path = [SpookyVoiceWeek.destination]
    }

    /// A `dubloon://` link: the game it names, on its own rather than on top of whatever was
    /// open. Every game opens for everyone; Pro is asked for inside, after the free takes.
    func open(_ link: DeepLink) {
        path = [link.gameMode]
    }

    func showPaywall(from source: HomePaywallSource) {
        paywallSource = source
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

    func presentBoothAnnouncementIfDue() {
        // Not once the free takes are used up: a note whose button leads to a paywall is an ad.
        // It is not marked shown either, so it is still due once they can record again.
        guard BoothCamAnnouncement.shared.isDue,
              access.canStartTake,
              !isBoothAnnouncementPresented else { return }
        #if DEBUG
        if ScreenshotMode.isActive { return }
        #endif
        isBoothAnnouncementPresented = true
        AnalyticsManager.shared.trackCustomEvent(name: "booth_announcement_shown", parameters: nil)
    }

    /// Marked on the way out rather than on the way in, so a user who kills the app
    /// mid-animation still gets told.
    func boothAnnouncementDidDisappear() {
        BoothCamAnnouncement.shared.markShown()
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
