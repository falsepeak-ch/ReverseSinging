//
//  EarlyAdopterTests.swift
//  ReverseSingingTests
//
//  The grandfather clause: who is recognised, and who is not
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Early Adopter")
struct EarlyAdopterTests {

    private static func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Recognising

    /// A device carrying any trace of earlier use is exempt.
    ///
    /// Each marker is checked on its own, because they cover different users: one
    /// who finished onboarding and stopped, one who only ever opened the dub
    /// library, one who saved a session. Missing any of them charges someone the
    /// clause was written for.
    @Test(arguments: [
        "hasCompletedOnboarding",
        "review.appOpenCount",
        "dub.starterPacksInstalled",
        "savedSessions",
        "uiMode"
    ])
    func anyTraceOfEarlierUseGrantsTheExemption(marker: String) {
        let defaults = Self.makeDefaults()
        defaults.set(true, forKey: marker)

        let earlyAdopter = EarlyAdopter(defaults: defaults)
        earlyAdopter.resolveFromLocalUsage()

        #expect(earlyAdopter.isEarlyAdopter,
                "an install carrying \(marker) predates the paywall and must not be charged")
    }

    /// A first launch on a clean install is not an early adopter.
    @Test func aFreshInstallIsNotExempt() {
        let defaults = Self.makeDefaults()
        let earlyAdopter = EarlyAdopter(defaults: defaults)

        earlyAdopter.resolveFromLocalUsage()

        #expect(earlyAdopter.isEarlyAdopter == false)
    }

    /// The question is asked once and never again.
    ///
    /// This is the whole reason the decision is persisted. A new user completes
    /// onboarding minutes after their first launch, which writes
    /// `hasCompletedOnboarding`; re-running the check on the *second* launch would
    /// then read that as "was here before the paywall" and hand out the exemption
    /// to precisely the people meant to pay.
    @Test func aNewUserWhoLaterCompletesOnboardingIsStillNotExempt() {
        let defaults = Self.makeDefaults()
        let earlyAdopter = EarlyAdopter(defaults: defaults)

        // First launch: clean.
        earlyAdopter.resolveFromLocalUsage()
        #expect(earlyAdopter.isEarlyAdopter == false)

        // They use the app, which writes the very markers the check looks for.
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(3, forKey: "review.appOpenCount")

        // Second launch: the answer must not change.
        earlyAdopter.resolveFromLocalUsage()
        #expect(earlyAdopter.isEarlyAdopter == false,
                "the exemption was re-decided after the app wrote its own usage markers")
    }

    // MARK: - Surviving a reinstall

    /// The cutoff the tests measure against. Arbitrary — the real one comes from
    /// Remote Config at runtime, which is the point of it being a parameter.
    private static let cutoff = Date(timeIntervalSince1970: 1_780_000_000)

    /// A download from before the paywall shipped is exempt even with no local
    /// traces left, which is what makes "free for life" survive a new phone.
    @Test func anOriginalDownloadBeforeTheCutoffGrantsTheExemption() {
        let defaults = Self.makeDefaults()
        let earlyAdopter = EarlyAdopter(defaults: defaults)

        earlyAdopter.resolveFromLocalUsage()
        #expect(earlyAdopter.isEarlyAdopter == false)

        earlyAdopter.considerOriginalPurchaseDate(
            Self.cutoff.addingTimeInterval(-86_400), before: Self.cutoff
        )
        #expect(earlyAdopter.isEarlyAdopter)
    }

    @Test func aDownloadAfterTheCutoffDoesNotGrantIt() {
        let defaults = Self.makeDefaults()
        let earlyAdopter = EarlyAdopter(defaults: defaults)
        earlyAdopter.resolveFromLocalUsage()

        earlyAdopter.considerOriginalPurchaseDate(
            Self.cutoff.addingTimeInterval(86_400), before: Self.cutoff
        )
        #expect(earlyAdopter.isEarlyAdopter == false)
    }

    /// Remote Config can move the cutoff later after a first, stricter evaluation.
    ///
    /// This is the ordering that actually happens on a cold launch: customer info
    /// can arrive before the config fetch lands, so the first check runs against
    /// the shipped default and a second against the console's value. The grant is
    /// one-way, so the later date can only add people.
    @Test func alaterCutoffFromRemoteConfigStillGrantsIt() {
        let defaults = Self.makeDefaults()
        let earlyAdopter = EarlyAdopter(defaults: defaults)
        earlyAdopter.resolveFromLocalUsage()
        let downloaded = Self.cutoff.addingTimeInterval(86_400)

        // First pass, against a cutoff that predates the download: no grant.
        earlyAdopter.considerOriginalPurchaseDate(downloaded, before: Self.cutoff)
        #expect(earlyAdopter.isEarlyAdopter == false)

        // Console says the real release was a week later than we shipped with.
        earlyAdopter.considerOriginalPurchaseDate(
            downloaded, before: Self.cutoff.addingTimeInterval(7 * 86_400)
        )
        #expect(earlyAdopter.isEarlyAdopter)
    }

    /// A missing receipt is not evidence of anything, and must not revoke an
    /// exemption already granted locally.
    @Test func anAbsentReceiptChangesNothing() {
        let defaults = Self.makeDefaults()
        defaults.set(true, forKey: "hasCompletedOnboarding")
        let earlyAdopter = EarlyAdopter(defaults: defaults)
        earlyAdopter.resolveFromLocalUsage()
        #expect(earlyAdopter.isEarlyAdopter)

        earlyAdopter.considerOriginalPurchaseDate(nil, before: Self.cutoff)
        #expect(earlyAdopter.isEarlyAdopter, "a nil receipt date revoked an exemption")
    }

    // MARK: - Parsing the console value

    /// The console holds a hand-typed `YYYY-MM-DD`.
    @Test func aWellFormedConsoleDateParsesAsUTC() {
        let parsed = RemoteConfigService.parseReleaseDate("2026-09-11")
        #expect(parsed == Date(timeIntervalSince1970: 1_789_084_800))
    }

    /// A typo must not parse, so the caller keeps the value it already had.
    ///
    /// The failure this guards is silent and expensive: an unparseable date read
    /// as 1970 would mean nobody's download predates the cutoff, and every early
    /// adopter who reinstalls starts being charged.
    @Test(arguments: ["", "11-09-2026", "September 11 2026", "not a date", "2026-13-01"])
    func amalformedConsoleDateDoesNotParse(value: String) {
        #expect(RemoteConfigService.parseReleaseDate(value) == nil)
    }

    /// `DateFormatter` is lenient about the separator and reads `2026/09/11` as the
    /// date the format spells with dashes. Pinned rather than fixed: it resolves to
    /// the same day, so an operator who types slashes gets what they meant instead
    /// of a silent fallback to the shipped default.
    @Test func aSlashSeparatedConsoleDateIsAcceptedAsTheSameDay() {
        #expect(
            RemoteConfigService.parseReleaseDate("2026/09/11")
                == RemoteConfigService.parseReleaseDate("2026-09-11")
        )
    }

    // MARK: - The welcome

    @Test func theWelcomeIsRememberedOnceShown() {
        let defaults = Self.makeDefaults()
        let earlyAdopter = EarlyAdopter(defaults: defaults)

        #expect(earlyAdopter.hasSeenWelcome == false)
        earlyAdopter.markWelcomeSeen()
        #expect(earlyAdopter.hasSeenWelcome)
    }
}
