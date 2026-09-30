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
/// and are enjoying themselves: from the third open, once they have shipped something (a share)
/// or have had a couple of results they were proud of (a win: a great score, an approved
/// impression). Wins count for everyone, so a player who only ever sings backwards for free is
/// asked as readily as one who paid. After an ask it waits a number of opens before it will ask
/// again, so the year's quota is not burned in a week.
///
/// Showing the prompt is the caller's job. This only decides, so it runs anywhere, tests included.
public struct ReviewPromptPolicy {

    /// Where the counters are kept.
    public struct Keys: Sendable {
        public var openCount: String
        public var shareCount: String
        public var winCount: String
        public var lastAskedAtOpenCount: String
        public var activeDayCount: String
        public var lastActiveDay: String
        public var hasImportedPack: String

        public init(
            openCount: String,
            shareCount: String,
            winCount: String,
            lastAskedAtOpenCount: String,
            activeDayCount: String = "review.activeDayCount",
            lastActiveDay: String = "review.lastActiveDay",
            hasImportedPack: String = "review.hasImportedPack"
        ) {
            self.openCount = openCount
            self.shareCount = shareCount
            self.winCount = winCount
            self.lastAskedAtOpenCount = lastAskedAtOpenCount
            self.activeDayCount = activeDayCount
            self.lastActiveDay = lastActiveDay
            self.hasImportedPack = hasImportedPack
        }

        /// The keys Dubloon has always used. Leave them as they are: the open count doubles as
        /// evidence that an install was in use before the paywall.
        public static let standard = Keys(
            openCount: "review.appOpenCount",
            shareCount: "review.sharedVideoCount",
            winCount: "review.winCount",
            lastAskedAtOpenCount: "review.lastAskedAtOpenCount"
        )
    }

    /// The open the first ask lands on.
    public let opensBeforeAsking: Int

    /// Shares that on their own make someone worth asking. A share is the strongest sign: they
    /// made something and sent it out.
    public let sharesBeforeAsking: Int

    /// Wins that on their own make someone worth asking. One great score can be luck; a second
    /// means they have got the hang of it and are having a good time.
    public let winsBeforeAsking: Int

    /// Opens that have to pass after one ask before the next.
    public let opensBetweenAsks: Int

    /// Different days the app has to have been opened on before our own review note is shown.
    public let activeDaysForBanner: Int

    private let defaults: UserDefaults
    private let keys: Keys

    public init(
        defaults: UserDefaults = .standard,
        keys: Keys = .standard,
        opensBeforeAsking: Int = 3,
        sharesBeforeAsking: Int = 1,
        winsBeforeAsking: Int = 2,
        opensBetweenAsks: Int = 10,
        activeDaysForBanner: Int = 3
    ) {
        self.defaults = defaults
        self.keys = keys
        self.opensBeforeAsking = opensBeforeAsking
        self.sharesBeforeAsking = sharesBeforeAsking
        self.winsBeforeAsking = winsBeforeAsking
        self.opensBetweenAsks = opensBetweenAsks
        self.activeDaysForBanner = activeDaysForBanner
    }

    // MARK: - Signals

    /// A launch, or a return from the background. The first one on a given day also counts
    /// that day as one the app was used on.
    public func registerAppOpen(now: Date = .now, calendar: Calendar = .current) {
        defaults.set(openCount + 1, forKey: keys.openCount)

        let day = calendar.startOfDay(for: now)
        if let lastDay = defaults.object(forKey: keys.lastActiveDay) as? Date, lastDay >= day { return }
        defaults.set(day, forKey: keys.lastActiveDay)
        defaults.set(activeDayCount + 1, forKey: keys.activeDayCount)
    }

    /// The user brought a dub pack of their own into the app, now or at some earlier time.
    public func registerImportedPack() {
        guard !hasImportedPack else { return }
        defaults.set(true, forKey: keys.hasImportedPack)
    }

    /// Something the user made actually left the app.
    public func registerShare() {
        defaults.set(shareCount + 1, forKey: keys.shareCount)
    }

    /// A result the player can be proud of: a great score, an approved impression.
    public func registerWin() {
        defaults.set(winCount + 1, forKey: keys.winCount)
    }

    /// The prompt was just requested, which starts the wait before the next one.
    public func recordAsked() {
        defaults.set(openCount, forKey: keys.lastAskedAtOpenCount)
    }

    // MARK: - Deciding

    public var isEligible: Bool {
        guard openCount >= opensBeforeAsking else { return false }
        guard shareCount >= sharesBeforeAsking || winCount >= winsBeforeAsking else { return false }

        let lastAsked = defaults.integer(forKey: keys.lastAskedAtOpenCount)
        return lastAsked == 0 || openCount - lastAsked >= opensBetweenAsks
    }

    public var openCount: Int { defaults.integer(forKey: keys.openCount) }
    public var shareCount: Int { defaults.integer(forKey: keys.shareCount) }
    public var winCount: Int { defaults.integer(forKey: keys.winCount) }
    /// Different days the app has been opened on. Counted from the version that added it, so
    /// an install from before starts at zero.
    public var activeDayCount: Int { defaults.integer(forKey: keys.activeDayCount) }
    public var hasImportedPack: Bool { defaults.bool(forKey: keys.hasImportedPack) }

    /// Who our own review note on the menu is for: someone who has brought in a dub pack of
    /// their own and has used the app on enough different days. Importing a pack is the
    /// deepest thing the app asks of anyone, and coming back for days says it was worth it,
    /// so their rating is a considered one.
    public var isBannerAudience: Bool {
        hasImportedPack && activeDayCount >= activeDaysForBanner
    }

    /// Clears every counter, as on a fresh install.
    public func reset() {
        for key in [
            keys.openCount, keys.shareCount, keys.winCount, keys.lastAskedAtOpenCount,
            keys.activeDayCount, keys.lastActiveDay, keys.hasImportedPack
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
