//
//  ImitationSoundLibraryTests.swift
//  ReverseSingingTests
//
//  Every bundled sound is there, named, and playable
//

import Testing
import Foundation
import AVFoundation
import DubScoring
import UIKit
@testable import ReverseSinging

@Suite("Imitation Sound Library") @MainActor
struct ImitationSoundLibraryTests {

    @Test func theManifestLoads() {
        #expect(ImitationSoundLibrary.all.count >= 20)
    }

    @Test func idsAreUnique() {
        let ids = ImitationSoundLibrary.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyCategoryHasSounds() {
        for category in ImitationCategory.allCases {
            #expect(!ImitationSoundLibrary.sounds(in: category).isEmpty, "\(category) is empty")
        }
    }

    /// Asset names must resolve in the compiled app, including non-animal categories.
    @Test(arguments: ImitationSoundLibrary.all)
    func everySoundHasBundledArtwork(sound: ImitationSound) throws {
        let image = try #require(UIImage(named: sound.artworkName), "Missing artwork for \(sound.id)")
        #expect(image.size.width > 0 && image.size.height > 0)
    }

    /// A missing file or an untranslated name would show up as a broken tile, not a crash,
    /// so it is caught here instead.
    @Test(arguments: ImitationSoundLibrary.all)
    func everySoundIsBundledAndNamed(sound: ImitationSound) throws {
        let url = try #require(sound.url, "\(sound.file) is not in the bundle")
        let file = try AVAudioFile(forReading: url)
        let seconds = Double(file.length) / file.processingFormat.sampleRate
        #expect(abs(seconds - sound.duration) < 0.1)
        #expect(sound.name != "imitate.sound.\(sound.id)", "\(sound.id) has no name")
        #expect(sound.license == "CC0-1.0")
    }

    /// A sound always scores near the top against itself; anything else means the scorer
    /// can't read the bundled format.
    @Test func aSoundScoresHighAgainstItself() throws {
        let sound = try #require(ImitationSoundLibrary.sound(id: "cat"))
        let url = try #require(sound.url)
        let score = try #require(ImitationScorer.score(takeURL: url, referenceURL: url))
        #expect(score.overall > 95)
    }
}

@Suite("Imitation Progress", .serialized) @MainActor
struct ImitationProgressStoreTests {

    private func makeStore() -> ImitationProgressStore {
        let name = "ImitationProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ImitationProgressStore(defaults: defaults)
    }

    @Test func aFirstScoreIsKeptButIsNotARecord() throws {
        let store = makeStore()
        let sound = try #require(ImitationSoundLibrary.all.first)

        #expect(!store.record(40, for: sound))
        #expect(store.best(for: sound) == 40)
    }

    @Test func onlyABetterScoreReplacesTheBest() throws {
        let store = makeStore()
        let sound = try #require(ImitationSoundLibrary.all.first)
        store.record(60, for: sound)

        #expect(!store.record(50, for: sound))
        #expect(store.best(for: sound) == 60)
        #expect(store.record(75, for: sound))
        #expect(store.best(for: sound) == 75)
    }
}
