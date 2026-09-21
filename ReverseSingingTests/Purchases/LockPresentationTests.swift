//
//  LockPresentationTests.swift
//  ReverseSingingTests
//
//  How a closed free window meets the user
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Lock Presentation")
struct LockPresentationTests {

    /// The shipped default: the menu stays open and the games on it are disabled.
    @Test func aClosedWindowDisablesTheGamesByDefault() {
        #expect(LockPresentation(state: .locked, isHardPaywallEnabled: false) == .soft)
    }

    /// The console can still ask for the paywall that covers everything.
    @Test func theConsoleCanBringTheHardPaywallBack() {
        #expect(LockPresentation(state: .locked, isHardPaywallEnabled: true) == .hard)
    }

    /// The flag chooses between two ways of being locked. It must never lock anyone by itself:
    /// a paying user, someone mid-trial, or a launch that has not heard from the store yet.
    @Test(arguments: [
        AccessState.unknown,
        .unlocked(.entitlement),
        .unlocked(.earlyAdopter),
        .unlocked(.gatingDisabled),
        .trial(daysRemaining: 1, endsAt: Date(timeIntervalSince1970: 0))
    ])
    func nothingIsPresentedUnlessLocked(state: AccessState) {
        #expect(LockPresentation(state: state, isHardPaywallEnabled: true) == .none)
        #expect(LockPresentation(state: state, isHardPaywallEnabled: false) == .none)
    }
}
