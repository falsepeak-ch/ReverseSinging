//
//  AudioFileManagerTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("AudioFileManager Tests")
struct AudioFileManagerTests {

    @Test func sharedInstance() {
        let manager1 = AudioFileManager.shared
        let manager2 = AudioFileManager.shared

        #expect(manager1 === manager2)
    }

    @Test func createTemporaryURL() {
        let manager = AudioFileManager.shared

        let url1 = manager.createTemporaryAudioURL()
        let url2 = manager.createTemporaryAudioURL()

        // CAF, not m4a: takes are recorded as LinearPCM so they can be analysed sample for
        // sample, scored, onset-aligned, sampled into a waveform, without a decode first.
        #expect(url1.pathExtension == "caf")
        #expect(url2.pathExtension == "caf")
        #expect(url1 != url2) // Should be unique
    }

    @Test func recordingsDirectory() {
        let manager = AudioFileManager.shared
        let recordingsDir = manager.recordingsDirectory()

        #expect(recordingsDir.lastPathComponent == "Recordings")
        #expect(recordingsDir.path().contains("Documents"))
    }
}
