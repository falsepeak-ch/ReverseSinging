//
//  ReviewPromptPolicy.swift
//  DubloonFoundation
//
//  When a star-rating prompt is worth spending
//

public import Foundation

/// Counts the signals that make a good moment to ask for an App Store review, and says when one
/// has come.
///
/// Apple caps the prompt at three appearances a year and silently drops the rest, so the only
/// thing worth spending is *which* moments get it. By default it asks people who have come back
/// and shipped something: at least one share, with the ask landing on the third open, before
/// they are deep in a take and would resent it. After an ask it waits a number of opens before it
/// will ask again, so the year's quota is not burned in a week.
///
/// Showing the prompt is the caller's job. This only decides, so it runs anywhere, tests included.
public struct ReviewPromptPolicy {

    /// Where the counters are kept.
    public struct Keys: Sendable {
        public var openCount: String
        public var shareCount: String
        public var lastAskedAtOpenCount: String

        public init(openCount: String, shareCount: String, lastAskedAtOpenCount: String) {
            self.openCount = openCount
            self.shareCount = shareCount
            self.lastAskedAtOpenCount = lastAskedAtOpenCount
        }

        /// The keys Dubloon has always used. Leave them as they are: the open count doubles as
        /// evidence that an install was in use before the paywall.
        public static let standard = Keys(
            openCount: "review.appOpenCount",
            shareCount: "review.sharedVideoCount",
            lastAskedAtOpenCount: "review.lastAskedAtOpenCount"
        )
    }

    /// The open the first ask lands on.
    public let opensBeforeAsking: Int

    /// Shares needed before asking. Someone who has never shared has not finished anything yet,
    /// and has nothing to rate.
    public let sharesBeforeAsking: Int

    /// Opens that have to pass after one ask before the next.
    public let opensBetweenAsks: Int

    private let defaults: UserDefaults
    private let keys: Keys

    public init(
        defaults: UserDefaults = .standard,
        keys: Keys = .standard,
        opensBeforeAsking: Int = 3,
        sharesBeforeAsking: Int = 1,
        opensBetweenAsks: Int = 10
    ) {
        self.defaults = defaults
        self.keys = keys
        self.opensBeforeAsking = opensBeforeAsking
        self.sharesBeforeAsking = sharesBeforeAsking
        self.opensBetweenAsks = opensBetweenAsks
    }

    // MARK: - Signals

    /// A launch, or a return from the background.
    public func registerAppOpen() {
        defaults.set(openCount + 1, forKey: keys.openCount)
    }

    /// Something the user made actually left the app.
    public func registerShare() {
        defaults.set(shareCount + 1, forKey: keys.shareCount)
    }

    /// The prompt was just requested, which starts the wait before the next one.
    public func recordAsked() {
        defaults.set(openCount, forKey: keys.lastAskedAtOpenCount)
    }

    // MARK: - Deciding

    public var isEligible: Bool {
        guard openCount >= opensBeforeAsking else { return false }
        guard shareCount >= sharesBeforeAsking else { return false }

        let lastAsked = defaults.integer(forKey: keys.lastAskedAtOpenCount)
        return lastAsked == 0 || openCount - lastAsked >= opensBetweenAsks
    }

    public var openCount: Int { defaults.integer(forKey: keys.openCount) }
    public var shareCount: Int { defaults.integer(forKey: keys.shareCount) }

    /// Clears every counter, as on a fresh install.
    public func reset() {
        for key in [keys.openCount, keys.shareCount, keys.lastAskedAtOpenCount] {
            defaults.removeObject(forKey: key)
        }
    }
}
