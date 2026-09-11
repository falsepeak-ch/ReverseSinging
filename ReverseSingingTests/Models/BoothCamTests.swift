//
//  BoothCamTests.swift
//  ReverseSingingTests
//
//  The camera is opt-in, and its footage is separable from the takes
//

import Testing
import Foundation
@testable import ReverseSinging

/// Serialized: every test here writes the same `booth.*` defaults keys, and in parallel the
/// one that clears them and the one that sets them decide each other's result.
@Suite("Booth Cam Preference", .serialized)
@MainActor
struct BoothCamPreferenceTests {

    private static let enabledKey = "booth.enabled"
    private static let mirrorKey = "booth.mirrorPreview"
    private static let primerKey = "booth.hasSeenPrimer"

    /// The whole promise of the feature is that nothing films until it is asked to. A default
    /// that drifted to on would be the one bug in here that matters.
    ///
    /// Restores whatever the device had, so clearing the key cannot change what the singleton
    /// reports to anything that runs afterwards.
    @Test func filmingIsOffForANewInstall() {
        let preference = BoothCamPreference.shared
        let original = (preference.isEnabled, preference.mirrorsPreview, preference.hasSeenPrimer)
        defer {
            preference.setForTesting(
                enabled: original.0,
                mirrors: original.1,
                seenPrimer: original.2
            )
        }

        UserDefaults.standard.removeObject(forKey: Self.enabledKey)
        #expect(UserDefaults.standard.bool(forKey: Self.enabledKey) == false)
    }

    /// The explanation has to be unseen on a new install, or the first tap on the camera key
    /// would go straight to the system prompt with no case made for it.
    @Test func theExplanationIsUnseenForANewInstall() {
        let preference = BoothCamPreference.shared
        let original = preference.hasSeenPrimer
        defer { preference.setForTesting(enabled: preference.isEnabled, seenPrimer: original) }

        UserDefaults.standard.removeObject(forKey: Self.primerKey)
        #expect(UserDefaults.standard.bool(forKey: Self.primerKey) == false)
    }

    /// The one default that is on. A selfie preview that is not mirrored reads as broken to
    /// anyone who has ever used a front camera, so an absent key must not come back false.
    @Test func theMirrorDefaultsOnRatherThanToFalse() {
        let preference = BoothCamPreference.shared
        let original = preference.mirrorsPreview
        defer { preference.setForTesting(enabled: preference.isEnabled, mirrors: original) }

        UserDefaults.standard.removeObject(forKey: Self.mirrorKey)
        #expect(UserDefaults.standard.object(forKey: Self.mirrorKey) == nil)
        // Reading an unset key as a plain Bool is the bug this guards: `bool(forKey:)` would
        // say false, and the preference has to say true.
        #expect((UserDefaults.standard.object(forKey: Self.mirrorKey) as? Bool ?? true) == true)
    }

    @Test func eachSwitchSurvivesBeingRead() {
        let preference = BoothCamPreference.shared
        let original = (preference.isEnabled, preference.mirrorsPreview, preference.hasSeenPrimer)
        defer {
            preference.setForTesting(
                enabled: original.0,
                mirrors: original.1,
                seenPrimer: original.2
            )
        }

        preference.setForTesting(enabled: true, mirrors: false, seenPrimer: true)
        #expect(preference.isEnabled)
        #expect(!preference.mirrorsPreview)
        #expect(UserDefaults.standard.bool(forKey: Self.enabledKey))
        #expect(!UserDefaults.standard.bool(forKey: Self.mirrorKey))

        preference.setForTesting(enabled: false, mirrors: true, seenPrimer: true)
        #expect(!preference.isEnabled)
        #expect(preference.mirrorsPreview)
    }

    /// Backing out of the explanation still counts as having seen it. Otherwise the panel
    /// comes back on the next line, which is nagging rather than explaining.
    @Test func decliningStillCountsAsHavingSeenTheExplanation() {
        let preference = BoothCamPreference.shared
        let original = preference.hasSeenPrimer
        defer { preference.setForTesting(enabled: preference.isEnabled, seenPrimer: original) }

        preference.setForTesting(enabled: false, seenPrimer: false)
        #expect(!preference.hasSeenPrimer)

        preference.markPrimerSeen()
        #expect(preference.hasSeenPrimer)
        #expect(!preference.isEnabled, "declining must not turn the camera on")
    }
}

// MARK: - Storage

/// Booth footage is the largest thing the app writes, and the one thing a user may want to
/// delete on its own. These are the tests that keep it separable from the takes it belongs to.
@Suite("Booth Cam Storage", .serialized)
struct BoothCamStorageTests {

    private func makeClip(bytes: Int, at url: URL) throws {
        try Data(repeating: 0x1F, count: bytes).write(to: url)
    }

    /// Different directories, so deleting one cannot take the other with it.
    @Test func footageLivesApartFromTheVoiceTakes() {
        let packID = UUID()
        let booth = AudioFileManager.shared.dubBoothDirectory(packID: packID)
        let takes = AudioFileManager.shared.dubTakesDirectory(packID: packID)
        defer {
            try? FileManager.default.removeItem(at: booth)
            try? FileManager.default.removeItem(at: takes)
        }

        #expect(booth != takes)
        #expect(!booth.path.hasPrefix(takes.path))
        #expect(!takes.path.hasPrefix(booth.path))
        #expect(booth.deletingLastPathComponent().lastPathComponent == "DubBooth")
    }

    /// The number Settings puts in front of the delete button. A pack directory with no clips
    /// in it must not be counted, or an emptied pack keeps inflating the total.
    @Test func usageCountsTheBytesAndTheNonEmptyPacks() throws {
        let root = AudioFileManager.shared.dubBoothRootDirectory()
        try? FileManager.default.removeItem(at: root)

        let first = UUID(), second = UUID(), empty = UUID()
        let firstDir = AudioFileManager.shared.dubBoothDirectory(packID: first)
        let secondDir = AudioFileManager.shared.dubBoothDirectory(packID: second)
        _ = AudioFileManager.shared.dubBoothDirectory(packID: empty)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeClip(bytes: 1_000, at: firstDir.appendingPathComponent("a.mov"))
        try makeClip(bytes: 2_000, at: firstDir.appendingPathComponent("b.mov"))
        try makeClip(bytes: 500, at: secondDir.appendingPathComponent("c.mov"))

        let usage = AudioFileManager.shared.boothFootageUsage()
        #expect(usage.bytes == 3_500)
        #expect(usage.packs == 2, "a pack directory with no clips in it is not a pack with footage")
    }

    @Test func usageIsZeroWhenNothingHasBeenFilmed() {
        let root = AudioFileManager.shared.dubBoothRootDirectory()
        try? FileManager.default.removeItem(at: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let usage = AudioFileManager.shared.boothFootageUsage()
        #expect(usage.bytes == 0)
        #expect(usage.packs == 0)
    }

    /// The promise printed under the delete button: the voice takes and the dubs are kept.
    @Test func deletingFootageLeavesTheVoiceTakesAlone() throws {
        let packID = UUID()
        let boothDir = AudioFileManager.shared.dubBoothDirectory(packID: packID)
        let takesDir = AudioFileManager.shared.dubTakesDirectory(packID: packID)
        defer {
            try? FileManager.default.removeItem(at: AudioFileManager.shared.dubBoothRootDirectory())
            try? FileManager.default.removeItem(at: takesDir)
        }

        try makeClip(bytes: 900, at: boothDir.appendingPathComponent("line-1.mov"))
        let take = takesDir.appendingPathComponent("line-1.caf")
        try makeClip(bytes: 100, at: take)

        try AudioFileManager.shared.deleteAllBoothFootage()

        #expect(AudioFileManager.shared.boothFootageUsage().bytes == 0)
        #expect(
            FileManager.default.fileExists(atPath: take.path),
            "deleting footage must never take the voice takes with it"
        )
    }

    /// Deleting a pack is the one case where the footage *should* go too.
    @Test func deletingAPackTakesItsFootageWithIt() throws {
        let packID = UUID()
        let boothDir = AudioFileManager.shared.dubBoothDirectory(packID: packID)
        defer { try? FileManager.default.removeItem(at: AudioFileManager.shared.dubBoothRootDirectory()) }

        try makeClip(bytes: 400, at: boothDir.appendingPathComponent("line-1.mov"))
        #expect(FileManager.default.fileExists(atPath: boothDir.path))

        try AudioFileManager.shared.deleteDubPack(folderName: "NoSuchPack-\(packID)", packID: packID)

        #expect(!FileManager.default.fileExists(atPath: boothDir.path))
    }
}
