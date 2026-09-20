//
//  SourceRefusalTests.swift
//  DubPackKitTests
//
//  What a source that is not a pack is refused as
//

import AVFoundation
import Foundation
import Testing
@testable import DubPackKit

@Suite("Source refusals")
struct SourceRefusalTests {

    @Test(arguments: [
        ("<!DOCTYPE html><html>", "html"),
        ("ID3\u{03}\u{00}", "mp3"),
        ("OggS", "ogg"),
        ("bplist00", "icloud_placeholder"),
        ("just some text", "text"),
        ("", "empty"),
    ])
    func namesWhatAFileReallyIs(head: String, expected: String) throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = temp.appending("scene.zip")
        try Data(head.utf8).write(to: file)

        #expect(ArchiveKind.detect(at: file) == nil)
        #expect(ArchiveKind.looksLike(file) == expected)
    }

    @Test func aZipThatIsAWebPageIsRefusedForWhatItIs() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = temp.appending("scene.zip")
        try Data("<!DOCTYPE html><html><body>Download expired</body></html>".utf8).write(to: file)

        await #expect(throws: DubPackImportError.unsupportedSource(fileExtension: "zip", looksLike: "html")) {
            try await DubPackInstaller.testing(library: temp.appending("library")).install(from: file)
        }
    }

    @Test func anICloudPlaceholderIsRefusedAsNotDownloaded() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = temp.appending("scene.zip")
        try Data("bplist00\u{00}".utf8).write(to: file)

        await #expect(throws: DubPackImportError.sourceNotDownloaded) {
            try await DubPackInstaller.testing(library: temp.appending("library")).install(from: file)
        }
    }

    @Test func environmentalFailuresAreMarkedInTheReport() {
        let report = DubPackIssueReport.importFailure(
            .sourceNotDownloaded, stage: .copying, sourceExtension: "zip", packTitle: "t"
        )
        #expect(report.severity == .informational)
        #expect(report.keys["environmental"] == .bool(true))

        let real = DubPackIssueReport.importFailure(.noPackFound, stage: .copying, sourceExtension: "zip", packTitle: "t")
        #expect(real.severity == .degraded)
    }

    @Test func cosmeticIssuesAreInformational() {
        let reports = DubPackIssueReport.reports(
            for: [
                .missingIcon(file: "icon.png"),
                .missingPackInfo(otherTextFiles: []),
                .missingStill(file: "001.txt", substitute: "000.jpg"),
                .droppedLine(file: "002.txt", reason: .missingAudio),
                .videoConversionFailed(file: "dub_video.ogv", failure: .noFrames),
                .audioConversionFailed(file: "003.ogg", failure: .corrupt(detail: "x")),
            ],
            packTitle: "t", candidateLineCount: 3, keptLineCount: 2
        )
        let bySeverity = Dictionary(grouping: reports, by: \.severity).mapValues { $0.map(\.kind) }

        #expect(Set(bySeverity[.informational] ?? []) == [.missingIcon, .missingPackInfo, .missingStills])
        #expect(Set(bySeverity[.degraded] ?? []) == [.droppedLines, .videoTranscode, .audioTranscode])
    }

    @Test func aDeferredVideoConversionIsInformationalAndSaysSo() {
        let reports = DubPackIssueReport.reports(
            for: [.videoConversionDeferred(file: "dub_video.ogv", failure: .interrupted)],
            packTitle: "t", candidateLineCount: 0, keptLineCount: 0
        )
        #expect(reports.count == 1)
        #expect(reports[0].severity == .informational)
        #expect(reports[0].keys["deferred"] == .bool(true))
        #expect(reports[0].keys["failure"] == .string("interrupted"))
    }

    @Test func writerErrorsAreReadByCodeNotMessage() {
        let interrupted = NSError(domain: AVFoundationErrorDomain, code: -11847, userInfo: [NSLocalizedDescriptionKey: "Vorgang unterbrochen"])
        let full = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        let wrapped = NSError(domain: "x", code: 1, userInfo: [NSUnderlyingErrorKey: full])
        let other = NSError(domain: "x", code: 2)

        #expect(VideoConversionFailure.writer(interrupted) == .interrupted)
        #expect(VideoConversionFailure.writer(full) == .diskFull)
        #expect(VideoConversionFailure.writer(wrapped) == .diskFull)
        #expect(VideoConversionFailure.writer(other) == .writerFailed(detail: other.localizedDescription))
        #expect(VideoConversionFailure.interrupted.isRetryable)
        #expect(!VideoConversionFailure.noFrames.isRetryable)
    }
}
