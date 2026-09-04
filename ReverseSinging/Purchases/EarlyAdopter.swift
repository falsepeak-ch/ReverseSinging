//
//  EarlyAdopter.swift
//  ReverseSinging
//
//  Who was already here before the app started charging, and therefore never pays.
//

import Foundation

/// The grandfather clause.
///
/// Everyone who was using Dubloon before the paywall shipped keeps both games for
/// life. They are the people who found the app when it was free and unknown, and
/// putting a wall in front of them would be charging them for something they
/// already have.
///
/// The hard part is not the exemption, it is *recognising* them, because at the
/// first launch of the build carrying the paywall an old install and a brand-new
/// one look identical from inside `AccessController`: neither has a trial anchor
/// yet. So the question is answered from traces the app was already leaving before
/// any of this existed.
///
/// It is answered **once**, on that first launch, and then remembered. It has to
/// be: `hasCompletedOnboarding` is true for a new user too, five minutes later, and
/// re-running the check would hand the exemption to exactly the people it is not
/// for.
struct EarlyAdopter {

    static let shared = EarlyAdopter()

    private enum Key {
        /// Whether the local question has been asked. Guards against asking twice.
        static let decided = "earlyAdopter.decided"
        /// The answer. Once true it never goes back to false.
        static let granted = "earlyAdopter.granted"
        /// Whether the welcome has been shown.
        static let welcomeSeen = "earlyAdopter.welcomeSeen"
    }

    /// Keys the app wrote before the paywall existed. Any one of them present at
    /// the first launch of this build means the app has been used before.
    ///
    /// Several rather than one because they cover different kinds of user: someone
    /// who skipped onboarding but played dub, someone who played once and never
    /// opened the dub library, someone who saved a session and deleted the packs.
    /// A false negative here charges a loyal user, so the test is deliberately
    /// generous.
    private static let usageMarkers = [
        "hasCompletedOnboarding",       // AudioViewModel, set on finishing onboarding
        "review.appOpenCount",          // ReviewPrompt, incremented on every open
        "dub.starterPacksInstalled",    // DubStarterPacks, written on first dub library open
        "savedSessions",                // AudioViewModel, any saved reverse-singing session
        "uiMode"                        // AudioViewModel, written when the interface is chosen
    ]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Reading

    var isEarlyAdopter: Bool { defaults.bool(forKey: Key.granted) }

    var hasSeenWelcome: Bool { defaults.bool(forKey: Key.welcomeSeen) }

    func markWelcomeSeen() {
        defaults.set(true, forKey: Key.welcomeSeen)
    }

    // MARK: - Deciding

    /// Answers the question from what is already on the device. Called once, at
    /// launch, before anything else this build writes.
    ///
    /// Order matters more than it looks: `ReviewPrompt` bumps its open counter and
    /// `AudioViewModel` writes `hasCompletedOnboarding` as soon as the first screen
    /// appears, so this has to run in `didFinishLaunching`, ahead of both.
    func resolveFromLocalUsage() {
        guard !defaults.bool(forKey: Key.decided) else { return }
        defaults.set(true, forKey: Key.decided)

        let hasUsedTheAppBefore = Self.usageMarkers.contains { defaults.object(forKey: $0) != nil }
        guard hasUsedTheAppBefore else { return }

        grant(source: "local_usage")
    }

    /// A second chance, from the App Store receipt.
    ///
    /// The local markers die with the app container: an early adopter who reinstalls,
    /// or moves to a new phone, looks brand new. "Free for life" that stops working
    /// when you change phone is not free for life, so the original download date —
    /// which follows the Apple Account rather than the device — is honoured too.
    ///
    /// Nil on a device where the receipt has not been fetched, which is why it is a
    /// supplement to the local check and not a replacement for it.
    ///
    /// `releaseDate` is the App Store release of the first version that charges,
    /// and comes from Remote Config rather than a constant: Apple decides the
    /// actual release date, often days after the build is cut, so it cannot be
    /// known when this is compiled. Getting it wrong in the too-early direction
    /// charges people who were here first, and that is not a mistake worth
    /// needing a release to correct.
    ///
    /// Safe to call repeatedly and with a changing cutoff — the grant is one-way,
    /// so a later, more accurate date can only ever add people, never remove them.
    func considerOriginalPurchaseDate(_ date: Date?, before releaseDate: Date) {
        guard !isEarlyAdopter, let date, date < releaseDate else { return }
        grant(source: "original_purchase_date")
    }

    private func grant(source: String) {
        defaults.set(true, forKey: Key.granted)
        AnalyticsManager.shared.trackEarlyAdopterGranted(source: source)
    }

    // MARK: - Testing

    #if DEBUG
    /// Puts the decision back so the first-launch path can be exercised again.
    func resetForTesting() {
        [Key.decided, Key.granted, Key.welcomeSeen].forEach(defaults.removeObject(forKey:))
    }

    /// Grants the exemption directly, for looking at the welcome screen.
    func grantForTesting() {
        defaults.set(true, forKey: Key.decided)
        defaults.set(true, forKey: Key.granted)
        defaults.set(false, forKey: Key.welcomeSeen)
    }
    #endif
}
