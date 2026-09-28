//
//  ReviewBanner.swift
//  ReverseSinging
//
//  The note on the menu that asks someone who bought Dubloon Pro for a review
//

import Foundation

/// Decides when the menu's review banner is up, for people who have paid.
///
/// Separate from `ReviewPrompt`, which spends Apple's rationed star-rating sheet on whoever has
/// come back and shared something. This one is ours: it links straight to the App Store's
/// write-a-review page, so it works every time it is tapped, and it is only ever shown to
/// someone who owns Dubloon Pro, who has already said with money that the app is worth
/// something.
///
/// It stays out of the way: "Not now" puts it away for `snoozeInterval`, a second "Not now"
/// puts it away for good, and so does tapping through to the store — whether or not a review
/// was actually written, which the app cannot know.
@MainActor
final class ReviewBanner {

    static let shared = ReviewBanner()

    /// The App Store's review form for Dubloon, rather than the product page.
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6754534073?action=write-review")!

    /// How long "Not now" puts the banner away for.
    static let snoozeInterval: TimeInterval = 7 * 24 * 60 * 60

    /// "Not now" this many times and it never comes back.
    static let dismissalsBeforeGivingUp = 2

    private enum Key {
        static let wentToStore = "reviewBanner.wentToStore"
        static let dismissCount = "reviewBanner.dismissCount"
        static let snoozedUntil = "reviewBanner.snoozedUntil"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Deciding

    /// Whether the banner may be on screen now. Whether the person has paid is the caller's to
    /// ask: this only knows what they did with the banner.
    func isDue(now: Date = .now) -> Bool {
        guard !defaults.bool(forKey: Key.wentToStore),
              dismissCount < Self.dismissalsBeforeGivingUp else { return false }
        guard let snoozedUntil = defaults.object(forKey: Key.snoozedUntil) as? Date else { return true }
        return now >= snoozedUntil
    }

    private var dismissCount: Int { defaults.integer(forKey: Key.dismissCount) }

    // MARK: - Answers

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
