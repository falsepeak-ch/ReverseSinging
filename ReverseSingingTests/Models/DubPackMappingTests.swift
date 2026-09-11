//
//  DubPackMappingTests.swift
//  ReverseSingingTests
//
//  Turning what DubPackKit read into the app's pack model
//

import DubPackKit
import Foundation
import Testing
@testable import ReverseSinging

@Suite("Dub Pack Mapping")
struct DubPackMappingTests {

    private let parsed = ParsedPack(
        title: "Camp Rules",
        authors: ["Blender Studio"],
        iconFile: nil,
        backingTrackFile: "_backing_track.m4a",
        videoFile: "dub_video.mp4",
        lines: [
            ParsedLine(
                index: 1, slug: "001_Rex", character: "Rex", caption: "Rules are rules.",
                imageFile: nil, referenceAudioFile: "001_Rex.wav", startTime: 1.25, duration: 2
            ),
        ],
        duration: 22.9,
        provenance: PackProvenance(
            source: "Sprite Fright (2021), Blender Studio",
            sourceURL: "https://studio.blender.org/projects/sprite-fright/",
            rights: "CC BY 4.0"
        )
    )

    @Test func carriesOverEverythingTheKitRead() {
        let id = UUID()
        let importedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let directory = URL(fileURLWithPath: "/tmp/does-not-exist/CampRules", isDirectory: true)

        let pack = DubPack(parsed: parsed, directory: directory, id: id, importedAt: importedAt)

        #expect(pack.id == id)
        #expect(pack.importedAt == importedAt)
        #expect(pack.folderName == "CampRules")
        #expect(pack.title == "Camp Rules")
        #expect(pack.authors == ["Blender Studio"])
        #expect(pack.backingTrackFile == "_backing_track.m4a")
        #expect(pack.videoFile == "dub_video.mp4")
        #expect(pack.duration == 22.9)
        #expect(pack.source == "Sprite Fright (2021), Blender Studio")
        #expect(pack.sourceURL == "https://studio.blender.org/projects/sprite-fright/")
        #expect(pack.rights == "CC BY 4.0")

        let line = pack.lines[0]
        #expect(line.slug == "001_Rex")
        #expect(line.character == "Rex")
        #expect(line.caption == "Rules are rules.")
        #expect(line.referenceAudioFile == "001_Rex.wav")
        #expect(line.startTime == 1.25)
        #expect(line.duration == 2)
    }

    /// The app's model predates optional stills and icons; an absent one is an empty name,
    /// which the picture views already show as black.
    @Test func mapsAbsentPicturesToEmptyNames() {
        let pack = DubPack(parsed: parsed, directory: URL(fileURLWithPath: "/tmp/CampRules"))

        #expect(pack.iconFile == "")
        #expect(pack.lines[0].imageFile == "")
    }

    /// A reference that cannot be read falls back to the whole chunk rather than no window:
    /// the pack still counts as measured, so it is not re-read on every launch.
    @Test func fallsBackToTheWholeChunkWhenTheReferenceWillNotRead() {
        let pack = DubPack(parsed: parsed, directory: URL(fileURLWithPath: "/tmp/does-not-exist/CampRules"))

        #expect(pack.lines[0].speech == DubSpeechWindow(start: 0, end: 2))
        #expect(pack.hasMeasuredSpeech)
    }
}
