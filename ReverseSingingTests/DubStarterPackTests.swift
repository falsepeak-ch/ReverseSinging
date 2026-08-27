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

/// Serialized, because every test in here installs a real pack.
///
/// Installing writes to one shared `DubPacks` directory and one shared `UserDefaults` key,
/// and `DubPackImporter.install` deletes any existing destination before copying — so two of
/// these running at once race on the same folder and one of them imports into a directory the
/// other just removed. It was survivable with two packs and stopped being so with three.
@Suite("Dub Starter Packs", .serialized)
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

    /// One animated, one classic — and exactly one of each.
    ///
    /// The pair is the point, not the number: the two play differently enough that a new
    /// player finds out which kind they like on the first open. Two helpings of the same kind
    /// would tell them nothing and cost another megabyte of download.
    @Test func oneOfEachKindShips() {
        #expect(DubStarterPacks.bundled.count == 2)
        #expect(DubStarterPacks.bundled.contains("CampRules"), "the animated one")
        #expect(DubStarterPacks.bundled.contains("StuckUp"), "the classic one")
    }

    /// Every shipped scene is cut from someone else's film, so every shipped scene has to say
    /// whose and on what terms.
    ///
    /// This is the assertion that would have caught the state the app shipped 1.3.0 in: the
    /// build was writing `source` and `rights` into each pack and nothing was reading them, so
    /// the CC BY credit existed only inside a zip. A missing field here means a pack is making
    /// a claim on someone else's work and saying nothing about it.
    @MainActor
    @Test func everyStarterPackSaysWhereItCameFrom() async throws {
        for name in DubStarterPacks.bundled {
            let pack = try #require(await DubStarterPacks.install(name))
            defer {
                try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
                DubStarterPacks.forgetInstallsForTesting()
            }

            #expect(pack.hasAttribution, "\(pack.title) claims no provenance")
            #expect(pack.source?.isEmpty == false, "\(pack.title) names no source work")
            #expect(pack.rights?.isEmpty == false, "\(pack.title) states no terms")
            #expect(pack.rightsLabel?.isEmpty == false, "\(pack.title)'s terms read as empty")

            // The share notice reads these too, and it is the screen that carries the credit
            // off the device. A pack that shows nothing there is one being posted uncredited.
            #expect(!pack.authors.isEmpty, "\(pack.title) names nobody in the library list")
        }
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

    /// The starter scenes are cut from one mono optical soundtrack, so no two reference chunks
    /// may overlap.
    ///
    /// This replaces an assertion that the opposite was true. When both scenes were written for
    /// the app, each deliberately had two characters speaking at once, because the mixer puts
    /// overlapping lines on separate lanes and a starter pack was a good place to show that
    /// off. Cut from real film that property is not merely absent but impossible: two voices on
    /// one mono track cannot be separated into one chunk per speaker, and where the dialogue is
    /// tight the *handles* around neighbouring lines would carry the same few frames of film
    /// audio twice, playing the identical waveform on top of itself.
    ///
    /// So the invariant is inverted, and it is the one the clip pipeline can actually get
    /// wrong. Overlap handling itself is still covered, by `DubOverlapExportTests`, which
    /// builds the overlap it needs rather than relying on a shipped pack to contain one.
    @MainActor
    @Test func starterPackChunksNeverOverlap() async throws {
        for name in DubStarterPacks.bundled {
            let pack = try #require(await DubStarterPacks.install(name))

            defer {
                try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
                DubStarterPacks.forgetInstallsForTesting()
            }

            for (previous, next) in zip(pack.lines, pack.lines.dropFirst()) {
                #expect(
                    next.startTime >= previous.endTime - 0.001,
                    "\(pack.title): \(next.slug) starts at \(next.startTime) before \(previous.slug) ends at \(previous.endTime)"
                )
            }
        }
    }

    /// A scene worth dubbing passes the line back and forth.
    ///
    /// A monologue is a reading, not a performance, and the reason to cut *these* stretches of
    /// film rather than the narrated ones is that they are conversations.
    @MainActor
    @Test func aStarterSceneIsAConversation() async throws {
        for name in DubStarterPacks.bundled {
            let pack = try #require(await DubStarterPacks.install(name))

            defer {
                try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
                DubStarterPacks.forgetInstallsForTesting()
            }

            let handovers = zip(pack.lines, pack.lines.dropFirst())
                .count { $0.character != $1.character }

            #expect(handovers >= 5, "\(pack.title) changes speaker only \(handovers) times")
        }
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

/// Serialized: both tests write the same `dub.scoringEnabled` key, and in parallel the one
/// that clears it and the one that sets it decide each other's result.
@Suite("Dub Scoring Preference", .serialized)
@MainActor
struct DubScoringPreferenceTests {

    /// Off unless asked for. Dubbing a scene badly is most of the fun, and a grade on every
    /// attempt turns a game into a test.
    ///
    /// Restores whatever the device had, so clearing the key here cannot change what the
    /// singleton reports to anything that runs afterwards.
    @Test func scoringIsOffForANewInstall() {
        let original = DubScoringPreference.shared.isEnabled
        defer { DubScoringPreference.shared.setForTesting(original) }

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
