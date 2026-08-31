//
//  ReviewPromptTests.swift
//  ReverseSingingTests
//
//  Who gets asked for a rating, and who is left alone
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Review Prompt")
@MainActor
struct ReviewPromptTests {

    /// A private suite per test, so the counters never touch the real app's defaults
    /// and two tests can never see each other's opens.
    private func makePrompt(_ name: String = UUID().uuidString) -> ReviewPrompt {
        ReviewPrompt(defaults: UserDefaults(suiteName: name)!)
    }

    @Test func aFreshInstallIsNotAsked() {
        #expect(makePrompt().isEligible == false)
    }

    @Test func opensAloneAreNotEnough() {
        let prompt = makePrompt()
        for _ in 0..<5 { prompt.registerAppOpen() }

        #expect(prompt.isEligible == false)
    }

    @Test func aShareAloneIsNotEnough() {
        let prompt = makePrompt()
        prompt.registerVideoShared()
        prompt.registerAppOpen()
        prompt.registerAppOpen()

        // Two opens and a share: the ask belongs on the next open, not this one.
        #expect(prompt.isEligible == false)
    }

    @Test func theThirdOpenAfterASharedVideoQualifies() {
        let prompt = makePrompt()
        prompt.registerAppOpen()
        prompt.registerAppOpen()
        prompt.registerVideoShared()
        prompt.registerAppOpen()

        #expect(prompt.isEligible)
    }

}
