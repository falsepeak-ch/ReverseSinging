//
//  DubStarterPackTests.swift
//  ReverseSingingTests
//
//  The scenes that ship with the app
//

import Testing
import Foundation
import AVFoundation
@testable import ReverseSinging

@Suite("Dub Starter Packs")
struct DubStarterPackTests {

    /// The zips have to actually be in the bundle. A missing resource is a build mistake that
    /// shows up as a permanently empty library, which nothing else would catch.
    @Test func everyBundledPackIsInTheApp() {
        for name in DubStarterPacks.bundled {
            #expect(
                Bundle.main.url(forResource: name, withExtension: "zip") != nil,
                "\(name).zip is not in the app bundle"
            )
        }
    }

    @Test func thereAreTwoOfThem() {
        #expect(DubStarterPacks.bundled.count == 2)
    }

    /// A starter pack is an ordinary pack once installed: it parses, it has lines, it has a
    /// backing track, and every line knows where its dialogue sits.
    @MainActor
    @Test func aStarterPackInstallsAndParses() async throws {
        let name = try #require(DubStarterPacks.bundled.first)
        let pack = try #require(await DubStarterPacks.install(name))

        defer {
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
            DubStarterPacks.forgetInstallsForTesting()
        }

        #expect(!pack.lines.isEmpty)
        #expect(pack.backingTrackFile != nil, "the scene should ship a bed")
        #expect(pack.duration > 10, "a scene worth dubbing is longer than a few seconds")
        #expect(pack.characters.count >= 3, "three voices is what makes it worth recording twice")

        #expect(pack.hasMeasuredSpeech, "speech windows are measured at import, not later")

        for line in pack.lines {
            #expect(!line.caption.isEmpty, "\(line.slug) has no caption to perform")
            #expect(line.duration > 0.4, "\(line.slug) is too short to be a line")
            #expect(line.duration < 8, "\(line.slug) is too long to hold in your head")
            #expect(
                FileManager.default.fileExists(atPath: pack.referenceAudioURL(for: line).path),
                "\(line.slug) has no reference audio"
            )
            #expect(
                FileManager.default.fileExists(atPath: pack.imageURL(for: line).path),
                "\(line.slug) has no still"
            )
        }
    }

    /// A starter pack ships a real scene video, not a slideshow of stills.
    ///
    /// The video is what the picture actually is: `DubScenePicture` plays it and the record
    /// screen seeks it to a single line. A pack that lost its video would silently fall back
    /// to frozen stills, which is exactly the regression this guards.
    @MainActor
    @Test func aStarterPackShipsAPlayableSceneVideo() async throws {
        for name in DubStarterPacks.bundled {
            let pack = try #require(await DubStarterPacks.install(name))
            defer {
                try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
                DubStarterPacks.forgetInstallsForTesting()
            }

            let videoURL = try #require(pack.videoURL, "\(pack.title) ships no scene video")
            #expect(FileManager.default.fileExists(atPath: videoURL.path))
            #expect(DubPackParser.hasReadableVideoTrack(at: videoURL),
                    "\(pack.title)'s video has no track AVFoundation can decode")

            // Long enough to cover the whole scene. `DubMixer` clamps the exported audio to
            // the video's length, so a short video would crop the tail off every export.
            let duration = try await AVURLAsset(url: videoURL).load(.duration).seconds
            #expect(duration >= pack.duration - 0.05,
                    "\(pack.title): video \(duration)s is shorter than the scene \(pack.duration)s")

            // And every line has picture to seek to.
            for line in pack.lines {
                #expect(line.startTime < duration, "\(line.slug) starts past the end of the video")
            }
        }
    }

    /// Both scenes are written with two characters speaking at once, because the mixer puts
    /// overlapping lines on separate lanes and a starter pack should show that off.
    @MainActor
    @Test func aStarterPackHasOverlappingDialogue() async throws {
        let name = try #require(DubStarterPacks.bundled.first)
        let pack = try #require(await DubStarterPacks.install(name))

        defer {
            try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
            DubStarterPacks.forgetInstallsForTesting()
        }

        let overlapping = pack.lines.contains { line in
            pack.lines.contains { other in
                other.slug != line.slug
                    && other.speechStartTime < line.speechEndTime
                    && other.speechEndTime > line.speechStartTime
            }
        }

        #expect(overlapping, "no two lines in \(pack.title) are ever spoken at once")
    }

    /// A pack the user deleted must stay deleted. Putting it back on every launch would make
    /// the delete button look broken.
    @MainActor
    @Test func aStarterPackIsNotReinstalledAfterItIsDeleted() async throws {
        DubStarterPacks.forgetInstallsForTesting()
        defer { DubStarterPacks.forgetInstallsForTesting() }

        let name = try #require(DubStarterPacks.bundled.first)
        #expect(DubStarterPacks.pending.contains(name))

        let pack = try #require(await DubStarterPacks.install(name))
        try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)

        #expect(!DubStarterPacks.pending.contains(name),
                "an installed starter pack must not come back once it is gone")
    }
}

@Suite("Dub Scoring Preference")
@MainActor
struct DubScoringPreferenceTests {

    /// Off unless asked for. Dubbing a scene badly is most of the fun, and a grade on every
    /// attempt turns a game into a test.
    @Test func scoringIsOffForANewInstall() {
        UserDefaults.standard.removeObject(forKey: "dub.scoringEnabled")
        #expect(UserDefaults.standard.bool(forKey: "dub.scoringEnabled") == false)
    }

    @Test func theToggleSurvivesBeingRead() {
        let preference = DubScoringPreference.shared
        let original = preference.isEnabled
        defer { preference.setForTesting(original) }

        preference.setForTesting(true)
        #expect(preference.isEnabled)
        #expect(UserDefaults.standard.bool(forKey: "dub.scoringEnabled"))

        preference.setForTesting(false)
        #expect(!preference.isEnabled)
        #expect(!UserDefaults.standard.bool(forKey: "dub.scoringEnabled"))
    }
}
