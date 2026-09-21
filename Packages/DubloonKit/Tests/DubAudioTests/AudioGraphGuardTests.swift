//
//  AudioGraphGuardTests.swift
//  DubAudioTests
//

import Foundation
import Testing
@testable import DubAudio

@Suite("Audio graph guard")
struct AudioGraphGuardTests {

    @Test func aRaisedExceptionBecomesAThrownError() {
        #expect(throws: AudioGraphGuard.RaisedException.self) {
            try AudioGraphGuard.attempt {
                NSException(name: .genericException, reason: "error -10868", userInfo: nil).raise()
            }
        }
    }

    @Test func theErrorCarriesTheExceptionsNameAndReason() throws {
        do {
            try AudioGraphGuard.attempt {
                NSException(name: NSExceptionName("com.apple.coreaudio.avfaudio"), reason: "player did not see an IO cycle", userInfo: nil).raise()
            }
            Issue.record("nothing was thrown")
        } catch {
            #expect(error.name == "com.apple.coreaudio.avfaudio")
            #expect(error.reason == "player did not see an IO cycle")
            #expect(error.description == "com.apple.coreaudio.avfaudio: player did not see an IO cycle")
        }
    }

    @Test func aBlockThatReturnsNormallySucceeds() {
        var ran = false
        #expect(AudioGraphGuard.succeeds { ran = true })
        #expect(ran)
        #expect(!AudioGraphGuard.succeeds { NSException(name: .genericException, reason: nil, userInfo: nil).raise() })
    }
}
