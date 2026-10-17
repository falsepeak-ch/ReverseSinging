//
//  ReviewPromptPolicyTests.swift
//  DubloonFoundationTests
//
//  Who gets asked for a rating, and who is left alone
//

import Foundation
import Testing
import DubloonFoundation

@Suite("Review Prompt Policy")
struct ReviewPromptPolicyTests {

    /// A private suite per test, so the counters never touch the real app's defaults and two
    /// tests can never see each other's opens.
    private func makePolicy(
        opensBeforeAsking: Int = 2,
        sharesBeforeAsking: Int = 1
    ) -> (policy: ReviewPromptPolicy, defaults: UserDefaults) {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let policy = ReviewPromptPolicy(
            defaults: defaults,
            opensBeforeAsking: opensBeforeAsking,
            sharesBeforeAsking: sharesBeforeAsking
        )
        return (policy, defaults)
    }

    @Test func aFreshInstallIsNotAsked() {
        #expect(makePolicy().policy.isEligible == false)
    }

    @Test func opensAloneAreNotEnough() {
        let (policy, _) = makePolicy()
        for _ in 0..<5 { policy.registerAppOpen() }

        #expect(policy.isEligible == false)
    }

    @Test func aShareOnTheFirstOpenWaits() {
        let (policy, _) = makePolicy()
        policy.registerAppOpen()
        policy.registerShare()

        // The first visit is for playing; the ask belongs on a return.
        #expect(policy.isEligible == false)
    }

    @Test func theSecondOpenAfterASharedVideoQualifies() {
        let (policy, _) = makePolicy()
        policy.registerAppOpen()
        policy.registerShare()
        policy.registerAppOpen()

        #expect(policy.isEligible)
    }

    /// Apple may swallow an ask without showing anything, so the wait after one is a few
    /// opens, not weeks of them.
    @Test func afterAskingItWaitsFiveOpensBeforeAskingAgain() {
        let (policy, _) = makePolicy()
        policy.registerShare()
        for _ in 0..<2 { policy.registerAppOpen() }
        #expect(policy.isEligible)

        policy.recordAsked()
        #expect(policy.isEligible == false)

        for _ in 0..<4 { policy.registerAppOpen() }
        #expect(policy.isEligible == false)

        policy.registerAppOpen()
        #expect(policy.isEligible)
    }

    /// Free players never share a dub, so one good score on a return visit is enough.
    @Test func oneWinOnTheSecondOpenQualifiesWithoutAShare() {
        let (policy, _) = makePolicy()
        for _ in 0..<2 { policy.registerAppOpen() }
        #expect(policy.isEligible == false)

        policy.registerWin()
        #expect(policy.isEligible)
    }

    @Test func winsOnTheFirstOpenWait() {
        let (policy, _) = makePolicy()
        policy.registerAppOpen()
        for _ in 0..<5 { policy.registerWin() }

        #expect(policy.isEligible == false)
    }

    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + Double(offset) * 86_400)
    }

    /// Opens on the same day are one day of use, however many there are.
    @Test func aDayOfUseIsCountedOnce() {
        let (policy, _) = makePolicy()
        for _ in 0..<4 { policy.registerAppOpen(now: day(0)) }
        #expect(policy.activeDayCount == 1)

        policy.registerAppOpen(now: day(1))
        #expect(policy.activeDayCount == 2)
    }

    /// Our own review note is for someone who imported a pack and came back on another day.
    @Test func theBannerIsForImportersOnTheirSecondDay() {
        let (policy, _) = makePolicy()
        policy.registerImportedPack()
        policy.registerAppOpen(now: day(0))
        policy.registerAppOpen(now: day(0))
        #expect(policy.isBannerAudience == false)

        policy.registerAppOpen(now: day(3))
        #expect(policy.isBannerAudience)
    }

    /// A free player who only sings backwards gets there on wins instead of an import.
    @Test func threeWinsOverTwoDaysAlsoQualifyForTheBanner() {
        let (policy, _) = makePolicy()
        policy.registerAppOpen(now: day(0))
        policy.registerAppOpen(now: day(1))
        for _ in 0..<2 { policy.registerWin() }
        #expect(policy.isBannerAudience == false)

        policy.registerWin()
        #expect(policy.isBannerAudience)
    }

    /// Days alone are not enough: without a pack of their own or a few wins, nobody is asked.
    @Test func daysWithoutAnImportOrWinsAreNotEnough() {
        let (policy, _) = makePolicy()
        for offset in 0..<4 { policy.registerAppOpen(now: day(offset)) }

        #expect(policy.isBannerAudience == false)
    }

    /// Wins on a single day are not enough either.
    @Test func winsOnOneDayAreNotEnoughForTheBanner() {
        let (policy, _) = makePolicy()
        policy.registerAppOpen(now: day(0))
        for _ in 0..<5 { policy.registerWin() }

        #expect(policy.isBannerAudience == false)
    }

    /// Installs already carry these counters, so moving them would reset everyone's history.
    @Test func theCountersLiveUnderTheKeysTheAppHasAlwaysUsed() {
        let (policy, defaults) = makePolicy()
        policy.registerAppOpen()
        policy.registerShare()

        #expect(defaults.integer(forKey: "review.appOpenCount") == 1)
        #expect(defaults.integer(forKey: "review.sharedVideoCount") == 1)
    }

    @Test func winsLiveUnderTheirOwnKey() {
        let (policy, defaults) = makePolicy()
        policy.registerWin()

        #expect(defaults.integer(forKey: "review.winCount") == 1)
    }

    @Test func theThresholdsCanBeTuned() {
        let (policy, _) = makePolicy(opensBeforeAsking: 1, sharesBeforeAsking: 0)
        policy.registerAppOpen()

        #expect(policy.isEligible)
    }

    @Test func resetForgetsEveryCounter() {
        let (policy, _) = makePolicy()
        policy.registerShare()
        policy.registerWin()
        for _ in 0..<2 { policy.registerAppOpen() }
        policy.recordAsked()

        policy.reset()

        #expect(policy.openCount == 0)
        #expect(policy.shareCount == 0)
        #expect(policy.winCount == 0)
        #expect(policy.isEligible == false)
    }
}
