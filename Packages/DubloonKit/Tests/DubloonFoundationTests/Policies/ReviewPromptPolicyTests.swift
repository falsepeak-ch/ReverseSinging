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
        opensBeforeAsking: Int = 3,
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

    @Test func aShareAloneIsNotEnough() {
        let (policy, _) = makePolicy()
        policy.registerShare()
        policy.registerAppOpen()
        policy.registerAppOpen()

        // Two opens and a share: the ask belongs on the next open, not this one.
        #expect(policy.isEligible == false)
    }

    @Test func theThirdOpenAfterASharedVideoQualifies() {
        let (policy, _) = makePolicy()
        policy.registerAppOpen()
        policy.registerAppOpen()
        policy.registerShare()
        policy.registerAppOpen()

        #expect(policy.isEligible)
    }

    /// Apple would swallow a second ask anyway; waiting keeps the year's quota from going in a week.
    @Test func afterAskingItWaitsTenOpensBeforeAskingAgain() {
        let (policy, _) = makePolicy()
        policy.registerShare()
        for _ in 0..<3 { policy.registerAppOpen() }
        #expect(policy.isEligible)

        policy.recordAsked()
        #expect(policy.isEligible == false)

        for _ in 0..<9 { policy.registerAppOpen() }
        #expect(policy.isEligible == false)

        policy.registerAppOpen()
        #expect(policy.isEligible)
    }

    /// The open count doubles as the early-adopter check's evidence of earlier use, so moving it
    /// would quietly charge people who were here first.
    @Test func theCountersLiveUnderTheKeysTheAppHasAlwaysUsed() {
        let (policy, defaults) = makePolicy()
        policy.registerAppOpen()
        policy.registerShare()

        #expect(defaults.integer(forKey: "review.appOpenCount") == 1)
        #expect(defaults.integer(forKey: "review.sharedVideoCount") == 1)
    }

    @Test func theThresholdsCanBeTuned() {
        let (policy, _) = makePolicy(opensBeforeAsking: 1, sharesBeforeAsking: 0)
        policy.registerAppOpen()

        #expect(policy.isEligible)
    }

    @Test func resetForgetsEveryCounter() {
        let (policy, _) = makePolicy()
        policy.registerShare()
        for _ in 0..<3 { policy.registerAppOpen() }
        policy.recordAsked()

        policy.reset()

        #expect(policy.openCount == 0)
        #expect(policy.shareCount == 0)
        #expect(policy.isEligible == false)
    }
}
