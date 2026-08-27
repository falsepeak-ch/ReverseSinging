//
//  DubContentGateTests.swift
//  ReverseSingingTests
//
//  The gate in front of every dub import
//

import Testing
import Foundation
@testable import ReverseSinging

/// Serialized: two of these write and clear the same `UserDefaults` key, so run in parallel
/// they clear it out from under each other. The guard assertion in the first test is what
/// caught that, and it stays — a fixture that silently fails to take would make the real
/// assertion pass for the wrong reason.
@Suite("Dub Content Gate", .serialized)
struct DubContentGateTests {

    /// The gate remembers nothing, and the flag 1.3.0 left behind gets cleared.
    ///
    /// This is the regression that matters. The gate used to persist a "yes, I already have
    /// them" and skip itself forever after, which meant the rights disclaimer and the pointer
    /// to where files come from were shown to a user exactly once — and never again to the
    /// people importing the most. If a future change starts honouring the old key again, the
    /// users it would silently skip are precisely the ones who have had it set since 1.3.0.
    @Test func theLegacyOwnershipFlagIsCleared() {
        DubContentGate.setLegacyOwnershipFlagForTesting()
        #expect(DubContentGate.legacyOwnershipFlagIsSetForTesting,
                "the fixture didn't take, so the assertion below would pass for the wrong reason")

        DubContentGate.clearLegacyOwnershipFlag()

        #expect(!DubContentGate.legacyOwnershipFlagIsSetForTesting,
                "an install updating from 1.3.0 still carries the flag that skipped the gate")
    }

    /// Clearing is safe on a fresh install, where the key was never written.
    @Test func clearingIsHarmlessWhenTheFlagWasNeverSet() {
        DubContentGate.clearLegacyOwnershipFlag()
        DubContentGate.clearLegacyOwnershipFlag()

        #expect(!DubContentGate.legacyOwnershipFlagIsSetForTesting)
    }

    /// The example source is the one the modal offers, and it has to survive being turned into
    /// the host string the "not affiliated with %@" disclaimer prints.
    @Test func theExampleSourceNamesItsHost() {
        #expect(DubContentSource.example.host == "gamebanana.com")
        #expect(DubContentSource.example.name == "GameBanana")
        #expect(DubContentSource.example.url.scheme == "https")
    }
}
