//
//  FreeTakesTests.swift
//  ReverseSinging
//
//  Seven free takes, counted across every game.
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Free Takes", .serialized) @MainActor
struct FreeTakesTests {

    private func makeDefaults() -> UserDefaults {
        let name = "FreeTakesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func withAccess(_ state: AccessState, used: Int, _ body: (AccessController) -> Void) {
        let access = AccessController.shared
        let previousState = access.state
        let previousUsed = access.freeTakesUsed
        access.overrideStateForTesting(state)
        access.overrideFreeTakesUsedForTesting(used)
        defer {
            access.overrideStateForTesting(previousState)
            access.overrideFreeTakesUsedForTesting(previousUsed)
        }
        body(access)
    }

    @Test func aNewInstallHasEveryFreeTake() {
        let takes = FreeTakes(defaults: makeDefaults())

        #expect(takes.used == 0)
        #expect(takes.remaining == FreeTakes.limit)
    }

    /// The count is shared by every game and survives a relaunch.
    @Test func eachTakeIsCountedAndRemembered() {
        let defaults = makeDefaults()
        let takes = FreeTakes(defaults: defaults)

        takes.recordUse()
        takes.recordUse()

        let relaunched = FreeTakes(defaults: defaults)
        #expect(relaunched.used == 2)
        #expect(relaunched.remaining == FreeTakes.limit - 2)
    }

    @Test func theRemainingCountNeverGoesNegative() {
        let takes = FreeTakes(defaults: makeDefaults())
        for _ in 0..<(FreeTakes.limit + 2) { takes.recordUse() }

        #expect(takes.remaining == 0)
    }

    /// One take short of the limit, another may still start; at the limit, it may not.
    @Test func aTakeMayStartWhileOneIsLeft() {
        withAccess(.locked, used: FreeTakes.limit - 1) { access in
            #expect(access.canStartTake)
        }
        withAccess(.locked, used: FreeTakes.limit) { access in
            #expect(!access.canStartTake)
            #expect(access.freeTakesLeft == 0)
        }
    }

    /// Dubloon Pro has no limit, and its takes are not counted.
    @Test func proIsNeverStoppedOrCounted() {
        withAccess(.unlocked(.entitlement), used: FreeTakes.limit) { access in
            #expect(access.canStartTake)
            #expect(!access.recordTake(.dub))
            #expect(access.freeTakesUsed == FreeTakes.limit)
        }
    }
}
