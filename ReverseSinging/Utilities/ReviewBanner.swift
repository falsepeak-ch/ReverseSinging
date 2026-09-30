//
//  ReviewBanner.swift
//  ReverseSinging
//
//  The note on the menu that asks how Dubloon is going, in stars, and what to do with the answer
//

import Foundation

/// Decides when the menu's review banner is up, and where a star rating given on it leads.
///
/// Separate from `ReviewPrompt`, which spends Apple's rationed star-rating sheet on whoever has
/// come back and shared something. This one is ours. It asks for a rating out of five first:
/// someone happy is offered the App Store's write-a-review page, and someone who is not is
/// asked what went wrong, in a note that comes to us and can be acted on. Who is asked at all is
/// `ReviewPromptPolicy.isBannerAudience`: people who imported a pack and came back for days.
///
/// It stays out of the way: "Not now" puts it away for `snoozeInterval`, a second "Not now"
/// puts it away for good, and so does tapping through to the store — whether or not a review
/// was actually written, which the app cannot know — or sending a note.
@MainActor
final class ReviewBanner {

    static let shared = ReviewBanner()

    /// The App Store's review form for Dubloon, rather than the product page.
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6754534073?action=write-review")!

    /// How long "Not now" puts the banner away for.
    static let snoozeInterval: TimeInterval = 7 * 24 * 60 * 60

    /// "Not now" this many times and it never comes back.
    static let dismissalsBeforeGivingUp = 2

    static let maximumStars = 5

    /// This many stars or more and the person is offered the App Store; fewer, and they are
    /// asked what went wrong instead.
    static let starsThatLeadToStore = 4

    /// A note is a few sentences. The cap keeps it inside what one Crashlytics value holds.
    static let feedbackCharacterLimit = 500

    /// What a rating on the banner leads to.
    enum Destination: Equatable {
        /// Offer the App Store's review form.
        case store
        /// Ask what went wrong.
        case feedback
    }

    static func destination(forStars stars: Int) -> Destination {
        stars >= starsThatLeadToStore ? .store : .feedback
    }

    private enum Key {
        static let wentToStore = "reviewBanner.wentToStore"
        static let sentFeedback = "reviewBanner.sentFeedback"
        static let dismissCount = "reviewBanner.dismissCount"
        static let snoozedUntil = "reviewBanner.snoozedUntil"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Deciding

    /// Whether the banner may be on screen now. Who it is for is the caller's to
    /// ask: this only knows what they did with the banner.
    func isDue(now: Date = .now) -> Bool {
        guard !defaults.bool(forKey: Key.wentToStore),
              !defaults.bool(forKey: Key.sentFeedback),
              dismissCount < Self.dismissalsBeforeGivingUp else { return false }
        guard let snoozedUntil = defaults.object(forKey: Key.snoozedUntil) as? Date else { return true }
        return now >= snoozedUntil
    }

    private var dismissCount: Int { defaults.integer(forKey: Key.dismissCount) }

    // MARK: - Answers

    /// They tapped a star. Not an answer yet: the dialog it opens can still be cancelled.
    func recordRated(stars: Int) {
        AnalyticsManager.shared.trackCustomEvent(name: "review_banner_rated", parameters: ["stars": stars])
    }

    /// They told us what went wrong. Returns false, and sends nothing, for an empty note.
    @discardableResult
    func recordFeedback(stars: Int, message: String) -> Bool {
        let note = String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.feedbackCharacterLimit))
        guard !note.isEmpty else { return false }

        defaults.set(true, forKey: Key.sentFeedback)
        AnalyticsManager.shared.trackCustomEvent(
            name: "review_feedback_sent", parameters: ["stars": stars, "length": note.count]
        )
        CrashReporter.shared.recordFeedback(note, stars: stars)
        return true
    }

    /// They told us by email instead, which is where the note goes with Share Usage Data off.
    func recordFeedbackSentByMail() {
        defaults.set(true, forKey: Key.sentFeedback)
    }

    /// They tapped through to the store.
    func recordWentToStore() {
        defaults.set(true, forKey: Key.wentToStore)
        AnalyticsManager.shared.trackCustomEvent(name: "review_banner_tapped", parameters: nil)
    }

    /// They said "Not now".
    func recordDismissed(now: Date = .now) {
        defaults.set(dismissCount + 1, forKey: Key.dismissCount)
        defaults.set(now.addingTimeInterval(Self.snoozeInterval), forKey: Key.snoozedUntil)
        AnalyticsManager.shared.trackCustomEvent(
            name: "review_banner_dismissed", parameters: ["dismiss_count": dismissCount]
        )
    }

    /// It came on screen. Counted so taps and dismissals have something to be a rate of.
    func recordShown() {
        AnalyticsManager.shared.trackCustomEvent(name: "review_banner_shown", parameters: nil)
    }
}
