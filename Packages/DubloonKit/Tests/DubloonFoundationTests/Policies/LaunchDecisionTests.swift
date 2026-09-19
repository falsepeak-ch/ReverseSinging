//
//  LaunchDecisionTests.swift
//  DubloonFoundationTests
//
//  A question about an install, asked once
//

import Foundation
import Testing
import DubloonFoundation

@Suite("Launch Decision")
struct LaunchDecisionTests {

    private static func makeDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func theFirstLaunchAsks() {
        let defaults = Self.makeDefaults()
        let decision = LaunchDecision(key: "question.decided", defaults: defaults)
        var asked = false

        #expect(decision.makeOnce { asked = true })
        #expect(asked)
        #expect(decision.isMade)
    }

    @Test func noLaterLaunchAsksAgain() {
        let defaults = Self.makeDefaults()
        LaunchDecision(key: "question.decided", defaults: defaults).makeOnce {}

        var asked = false
        let ran = LaunchDecision(key: "question.decided", defaults: defaults).makeOnce { asked = true }

        #expect(!ran)
        #expect(!asked)
    }

    /// The answer usually writes the very markers a second asking would read. The question is
    /// recorded as asked before it is answered, so nothing the answer writes can reopen it.
    @Test func theQuestionIsRecordedBeforeItIsAnswered() {
        let defaults = Self.makeDefaults()
        let decision = LaunchDecision(key: "question.decided", defaults: defaults)
        var wasRecorded = false

        decision.makeOnce { wasRecorded = decision.isMade }

        #expect(wasRecorded)
    }

    @Test func resettingAsksAgain() {
        let defaults = Self.makeDefaults()
        let decision = LaunchDecision(key: "question.decided", defaults: defaults)
        decision.makeOnce {}

        decision.reset()

        #expect(!decision.isMade)
        var asked = false
        decision.makeOnce { asked = true }
        #expect(asked)
    }

    @Test func separateQuestionsAreRememberedSeparately() {
        let defaults = Self.makeDefaults()
        LaunchDecision(key: "first.decided", defaults: defaults).makeOnce {}

        #expect(LaunchDecision(key: "first.decided", defaults: defaults).isMade)
        #expect(!LaunchDecision(key: "second.decided", defaults: defaults).isMade)
    }

    // MARK: - Evidence

    /// A marker that was written as `false` or `0` is still evidence the app ran.
    @Test func anyStoredValueCountsAsEvidence() {
        let defaults = Self.makeDefaults()
        #expect(!defaults.containsValue(forAnyOf: ["hasCompletedOnboarding", "review.appOpenCount"]))

        defaults.set(false, forKey: "hasCompletedOnboarding")
        #expect(defaults.containsValue(forAnyOf: ["hasCompletedOnboarding", "review.appOpenCount"]))

        defaults.removeObject(forKey: "hasCompletedOnboarding")
        defaults.set(0, forKey: "review.appOpenCount")
        #expect(defaults.containsValue(forAnyOf: ["hasCompletedOnboarding", "review.appOpenCount"]))
    }

    @Test func noKeysIsNoEvidence() {
        #expect(!Self.makeDefaults().containsValue(forAnyOf: []))
    }
}
