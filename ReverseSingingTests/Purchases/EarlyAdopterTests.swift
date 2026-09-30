//
//  EarlyAdopterTests.swift
//  ReverseSingingTests
//
//  The grandfather clause: who is recognised, and who is not
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Early Adopter") @MainActor
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

    // MARK: - The welcome

    @Test func theWelcomeIsRememberedOnceShown() {
        let defaults = Self.makeDefaults()
        let earlyAdopter = EarlyAdopter(defaults: defaults)

        #expect(earlyAdopter.hasSeenWelcome == false)
        earlyAdopter.markWelcomeSeen()
        #expect(earlyAdopter.hasSeenWelcome)
    }
}
