//
//  DubBoothReelViewModelTests.swift
//  ReverseSingingTests
//
//  Which booth clip is up at any point in the scene
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Dub Booth Reel")
struct DubBoothReelViewModelTests {

    private func line(_ index: Int, start: TimeInterval, duration: TimeInterval) -> DubLine {
        let slug = String(format: "%03d_Tester", index)
        return DubLine(
            index: index,
            slug: slug,
            character: "Tester",
            caption: "line \(index)",
            imageFile: "\(slug).jpg",
            referenceAudioFile: "\(slug).wav",
            startTime: start,
            duration: duration
        )
    }

    private func pack(_ lines: [DubLine]) -> DubPack {
        DubPack(
            id: UUID(),
            title: "Reel Pack",
            authors: [],
            iconFile: "icon.jpg",
            backingTrackFile: nil,
            folderName: "reel-\(UUID().uuidString)",
            lines: lines,
            duration: 20
        )
    }

    /// Only lines with footage go on the reel, and in scene order, whatever order the set
    /// hands them back in.
    @Test func onlyLinesWithFootageAreOnTheReel() {
        let pack = pack([
            line(1, start: 0, duration: 2),
            line(2, start: 3, duration: 2),
            line(3, start: 6, duration: 2)
        ])

        let clips = DubBoothReelViewModel.clips(for: pack, slugs: ["003_Tester", "001_Tester"])

        #expect(clips.map(\.slug) == ["001_Tester", "003_Tester"])
        #expect(clips.map(\.start) == [0, 6])
        #expect(clips.map(\.end) == [2, 8])
        #expect(clips.allSatisfy { $0.url.lastPathComponent == "\($0.slug).mov" })
    }

    /// A line of no length has no footage worth showing, and would otherwise be a clip that
    /// is never up.
    @Test func aZeroLengthLineIsLeftOff() {
        let pack = pack([line(1, start: 0, duration: 0), line(2, start: 1, duration: 2)])

        let clips = DubBoothReelViewModel.clips(for: pack, slugs: ["001_Tester", "002_Tester"])

        #expect(clips.map(\.slug) == ["002_Tester"])
    }

    /// The clip under the head, or nothing in the gaps and after the last one.
    @Test func theClipUnderTheHeadIsChosen() {
        let pack = pack([line(1, start: 1, duration: 2), line(2, start: 5, duration: 2)])
        let clips = DubBoothReelViewModel.clips(for: pack, slugs: ["001_Tester", "002_Tester"])

        #expect(DubBoothReelViewModel.clip(at: 0.5, in: clips) == nil)
        #expect(DubBoothReelViewModel.clip(at: 1.0, in: clips)?.slug == "001_Tester")
        #expect(DubBoothReelViewModel.clip(at: 2.99, in: clips)?.slug == "001_Tester")
        #expect(DubBoothReelViewModel.clip(at: 3.0, in: clips) == nil, "a clip ends where its line does")
        #expect(DubBoothReelViewModel.clip(at: 6.0, in: clips)?.slug == "002_Tester")
        #expect(DubBoothReelViewModel.clip(at: 9.0, in: clips) == nil)
    }

    /// Lines can overlap. The monitor shows one thing, so the earlier line keeps it until it
    /// ends, the same way the export lays the earlier clip first.
    @Test func anEarlierLineKeepsTheMonitorThroughAnOverlap() {
        let pack = pack([line(1, start: 0, duration: 4), line(2, start: 2, duration: 4)])
        let clips = DubBoothReelViewModel.clips(for: pack, slugs: ["001_Tester", "002_Tester"])

        #expect(DubBoothReelViewModel.clip(at: 3.0, in: clips)?.slug == "001_Tester")
        #expect(DubBoothReelViewModel.clip(at: 4.0, in: clips)?.slug == "002_Tester")
    }
}
