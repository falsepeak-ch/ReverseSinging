//
//  InstallerReportingTests.swift
//  DubPackKitTests
//
//  What an install tells the crash reporter
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("Installer reporting")
struct InstallerReportingTests {

    private func makeSource(in temp: TemporaryDirectory) throws -> PackBuilder {
        let pack = try PackBuilder(in: temp.appending("source"), named: "Reported Scene")
        try pack.packInfo(["title=\"Reported Scene\""])
        try pack.line("001_Hero", at: 0)
        try pack.line("002_Hero", at: 2)
        return pack
    }

    @Test func leavesBreadcrumbsForEveryStage() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let source = try makeSource(in: temp)

        _ = try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: source.directory)

        #expect(reporter.breadcrumbs == [
            "dub_pack.import began (.)",
            "dub_pack.import staged",
            "dub_pack.import installed",
            "dub_pack.import converted",
            "dub_pack.import read",
        ])
    }

    @Test func aWholePackRecordsNothing() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let source = try makeSource(in: temp)

        _ = try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: source.directory)

        #expect(reporter.reports.isEmpty)
    }

    @Test func recordsEachKindOfIssueOnceWithThePacksTitle() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let source = try makeSource(in: temp)
        try source.entry("003_Hero", ["dub_timestamps=[4]"])
        try source.entry("004_Hero", ["dub_timestamps=[5]"])
        try source.remove("002_Hero.jpg")

        let installed = try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: source.directory)

        #expect(installed.pack.lines.count == 2)
        #expect(reporter.kinds == [.droppedLines, .missingStills])
        let dropped = try #require(reporter.report(.droppedLines))
        #expect(dropped.keys["pack_title"] == .string("Reported Scene"))
        #expect(dropped.keys["dropped_count"] == .int(2))
        #expect(dropped.keys["candidate_count"] == .int(4))
        #expect(dropped.keys["kept_count"] == .int(2))
    }

    /// The most broken pack is the one that most needs explaining.
    @Test func aPackWithNoLinesReportsItsDropsAndThenTheFailure() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let pack = try PackBuilder(in: temp.appending("source"), named: "Hollow")
        try pack.packInfo()
        try pack.entry("001_Hero", ["caption=\"never timed\""])

        await #expect(throws: DubPackImportError.self) {
            try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: pack.directory)
        }

        #expect(reporter.kinds == [.droppedLines, .importFailed])
        let failure = try #require(reporter.report(.importFailed))
        #expect(failure.keys["failure"] == .string("no_lines"))
        #expect(failure.keys["stage"] == .string("reading"))
        #expect(failure.keys["pack_title"] == .string("Hollow"))
        #expect(reporter.breadcrumbs.last == "dub_pack.import failed no_lines")
    }

    @Test func recordsAVideoThatWouldNotConvert() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let source = try makeSource(in: temp)
        try source.write(Data(count: 4096), to: "dub_video.ogv")

        _ = try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: source.directory)

        let report = try #require(reporter.report(.videoTranscode))
        #expect(report.keys["failure"] == .string("not_theora"))
        #expect(report.keys["pack_title"] == .string("Reported Scene"))
    }

    @Test func recordsAnArchiveItCannotOpen() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let rar = temp.appending("Something.rar")
        try Data("Rar!".utf8).write(to: rar)

        await #expect(throws: DubPackImportError.self) {
            try await DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter).install(from: rar)
        }

        #expect(reporter.reports == [DubPackIssueReport(
            kind: .importFailed,
            reason: "Import failed: unsupported_source",
            keys: [
                "pack_title": .string("Something"),
                "failure": .string("unsupported_source"),
                "stage": .string("copying"),
                "source_extension": .string("rar"),
                "detail": .string("rar"),
            ]
        )])
    }

    /// Somebody changing their mind is not a pack that failed.
    @Test func aCancelledInstallRecordsNoFailure() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let reporter = RecordingIssueReporter()
        let source = try makeSource(in: temp)
        let installer = DubPackInstaller.testing(library: temp.appending("library"), reporter: reporter)

        let task = Task { try await installer.install(from: source.directory) }
        task.cancel()
        _ = await task.result

        #expect(reporter.reports.isEmpty)
        #expect(reporter.breadcrumbs.last == "dub_pack.import failed cancelled")
    }
}
