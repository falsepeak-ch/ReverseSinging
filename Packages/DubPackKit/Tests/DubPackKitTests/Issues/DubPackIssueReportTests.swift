//
//  DubPackIssueReportTests.swift
//  DubPackKitTests
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("Issue reports")
struct DubPackIssueReportTests {

    /// Codes group non-fatals in the crash reporter. Renumbering one splits its history.
    @Test func kindCodesNeverChange() {
        let codes = Dictionary(uniqueKeysWithValues: DubPackIssueReport.Kind.allCases.map { ($0.rawValue, $0.code) })

        #expect(codes == [
            "dropped_lines": 1, "extra_timestamps": 2, "missing_stills": 3, "missing_icon": 4,
            "missing_pack_info": 5, "unreadable_pack_info": 6, "ambiguous_backing_track": 7,
            "unplayable_backing_track": 8, "ambiguous_video": 9, "unplayable_video": 10,
            "video_transcode": 11, "skipped_archive_entries": 12, "no_line_entries": 13,
            "recovered_archive": 14, "import": 100,
        ])
    }

    /// Contexts that were already in production before the package existed.
    @Test func keepsTheContextNamesAlreadyInUse() {
        #expect(DubPackIssueReport.Kind.droppedLines.context == "dub_pack.dropped_lines")
        #expect(DubPackIssueReport.Kind.unplayableBackingTrack.context == "dub_pack.unplayable_backing_track")
        #expect(DubPackIssueReport.Kind.unplayableVideo.context == "dub_pack.unplayable_video")
        #expect(DubPackIssueReport.Kind.videoTranscode.context == "dub_pack.video_transcode")
        #expect(DubPackIssueReport.Kind.importFailed.context == "dub_pack.import")
    }

    @Test func sendsOneReportPerKindInKindOrder() {
        let reports = DubPackIssueReport.reports(
            for: [
                .missingStill(file: "003_A.txt", substitute: "002_A.jpg"),
                .droppedLine(file: "001_A.txt", reason: .missingAudio),
                .droppedLine(file: "002_A.txt", reason: .missingTimestamp),
                .unplayableBackingTrack(file: "_backing_track.ogg"),
            ],
            packTitle: "Scene",
            candidateLineCount: 10,
            keptLineCount: 8
        )

        #expect(reports.map(\.kind) == [.droppedLines, .missingStills, .unplayableBackingTrack])
    }

    @Test func describesDroppedLines() throws {
        let report = try #require(DubPackIssueReport.reports(
            for: [
                .droppedLine(file: "001_A.txt", reason: .missingAudio),
                .droppedLine(file: "002_A.txt", reason: .missingTimestamp),
                .droppedLine(file: "003_A.txt", reason: .missingAudio),
            ],
            packTitle: "Scene",
            candidateLineCount: 60,
            keptLineCount: 57
        ).first)

        #expect(report.context == "dub_pack.dropped_lines")
        #expect(report.reason == "3 of 60 entries dropped (missing_audio, no_timestamp)")
        #expect(report.keys == [
            "pack_title": .string("Scene"),
            "dropped_count": .int(3),
            "candidate_count": .int(60),
            "kept_count": .int(57),
            "reasons": .string("missing_audio, no_timestamp"),
            "sample": .string("001_A.txt (missing_audio), 002_A.txt (no_timestamp), 003_A.txt (missing_audio)"),
        ])
    }

    @Test func capsTheSampleAndClipsLongText() throws {
        let issues = (1...9).map { DubPackIssue.missingStill(file: String(repeating: "x", count: 80) + "\($0).txt", substitute: nil) }
        let report = try #require(DubPackIssueReport.reports(
            for: issues,
            packTitle: String(repeating: "T", count: 300),
            candidateLineCount: 9,
            keptLineCount: 9
        ).first)

        guard case .string(let sample) = report.keys["sample"], case .string(let title) = report.keys["pack_title"] else {
            Issue.record("sample and title should be strings")
            return
        }
        let items = sample.components(separatedBy: ", ")
        #expect(items.count == DubPackIssueReport.sampleLimit)
        #expect(items.allSatisfy { $0.count == DubPackIssueReport.sampleItemLength })
        #expect(title.count == DubPackIssueReport.titleLength)
        #expect(report.keys["missing_count"] == .int(9))
    }

    @Test func describesAFailedVideoConversion() throws {
        let report = try #require(DubPackIssueReport.reports(
            for: [.videoConversionFailed(file: "dub_video.ogv", failure: .lengthMismatch(expected: 9, actual: 3.5))],
            packTitle: "Scene",
            candidateLineCount: 2,
            keptLineCount: 2
        ).first)

        #expect(report.context == "dub_pack.video_transcode")
        #expect(report.keys["source_extension"] == .string("ogv"))
        #expect(report.keys["failure"] == .string("length_mismatch"))
        #expect(report.keys["expected_seconds"] == .double(9))
        #expect(report.keys["actual_seconds"] == .double(3.5))
    }

    @Test func describesAPackWithNoLineEntries() throws {
        let report = try #require(DubPackIssueReport.reports(
            for: [.noLineEntries(fileTypes: ["mp3": 38, "ini": 38, "jpg": 38, "ogv": 1, "": 1])],
            packTitle: "Shrek 2",
            candidateLineCount: 0,
            keptLineCount: 0
        ).first)

        #expect(report.context == "dub_pack.no_line_entries")
        #expect(report.reason == "No line entries among 116 files")
        #expect(report.keys["file_types"] == .string("ini: 38, jpg: 38, mp3: 38, none: 1, ogv: 1"))
        #expect(report.keys["file_count"] == .int(116))
    }

    @Test func describesARecoveredArchive() throws {
        let cutOff = try #require(DubPackIssueReport.reports(
            for: [.archiveRecovered(truncatedEntry: "_backing_track.mp3", partialKept: true, damagedEntries: 0)],
            packTitle: "Forrest Gump",
            candidateLineCount: 7,
            keptLineCount: 7
        ).first)
        let damaged = try #require(DubPackIssueReport.reports(
            for: [.archiveRecovered(truncatedEntry: nil, partialKept: false, damagedEntries: 2)],
            packTitle: "Forrest Gump",
            candidateLineCount: 7,
            keptLineCount: 5
        ).first)

        #expect(cutOff.context == "dub_pack.recovered_archive")
        #expect(cutOff.reason == "The archive ends partway through _backing_track.mp3")
        #expect(cutOff.keys["truncated_entry"] == .string("_backing_track.mp3"))
        #expect(cutOff.keys["partial_kept"] == .bool(true))
        #expect(damaged.keys["truncated_entry"] == .string(""))
        #expect(damaged.keys["damaged_count"] == .int(2))
    }

    @Test func describesAFailedImport() {
        let report = DubPackIssueReport.importFailure(
            .archiveUnreadable(.corrupt(detail: "open: archive is truncated")),
            stage: .copying,
            sourceExtension: "7z",
            packTitle: "Scene"
        )

        #expect(report.context == "dub_pack.import")
        #expect(report.kind.code == 100)
        #expect(report.keys == [
            "pack_title": .string("Scene"),
            "failure": .string("archive.corrupt"),
            "stage": .string("copying"),
            "source_extension": .string("7z"),
            "detail": .string("open: archive is truncated"),
        ])
    }

    /// Every issue maps to a report, and no report kind is left without an issue or failure.
    @Test func everyIssueHasAKindAndEveryKindIsReachable() {
        let issues: [DubPackIssue] = [
            .droppedLine(file: "a", reason: .missingAudio),
            .noLineEntries(fileTypes: ["ini": 2]),
            .extraTimestampsIgnored(file: "a", count: 1),
            .missingStill(file: "a", substitute: nil),
            .missingIcon(file: "a.png"),
            .missingPackInfo(otherTextFiles: []),
            .unreadablePackInfo(file: "a"),
            .ambiguousBackingTrack(candidates: ["a", "b"]),
            .unplayableBackingTrack(file: "a.ogg"),
            .ambiguousSceneVideo(candidates: ["a", "b"]),
            .unplayableSceneVideo(file: "a.ogv"),
            .videoConversionFailed(file: "a.ogv", failure: .noFrames),
            .archiveRecovered(truncatedEntry: "a.mp3", partialKept: true, damagedEntries: 0),
            .unsafeArchiveEntriesSkipped(count: 1),
        ]

        let reports = DubPackIssueReport.reports(for: issues, packTitle: "P", candidateLineCount: 1, keptLineCount: 1)

        #expect(Set(reports.map(\.kind)) == Set(DubPackIssueReport.Kind.allCases).subtracting([.importFailed]))
        #expect(reports.allSatisfy { $0.keys["pack_title"] == .string("P") && !$0.reason.isEmpty })
    }
}
