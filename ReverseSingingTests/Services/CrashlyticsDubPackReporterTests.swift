//
//  CrashlyticsDubPackReporterTests.swift
//  ReverseSingingTests
//
//  What reaches Crashlytics when a dub pack will not parse
//

import AVFoundation
import DubPackKit
import Foundation
import Testing
@testable import ReverseSinging

/// Stands in for `CrashReporter`, keeping what would have been sent.
private final class RecordingSink: CrashReportingSink, @unchecked Sendable {
    struct Record {
        let error: NSError
        let context: String
        let keys: [String: Any]
    }

    private let lock = NSLock()
    private var storedLogs: [String] = []
    private var storedRecords: [Record] = []

    var logs: [String] { lock.withLock { storedLogs } }
    var records: [Record] { lock.withLock { storedRecords } }

    func log(_ message: String) {
        lock.withLock { storedLogs.append(message) }
    }

    func record(_ error: Error, context: String, keys: [String: Any]) {
        lock.withLock { storedRecords.append(Record(error: error as NSError, context: context, keys: keys)) }
    }
}

@Suite("Crashlytics Dub Pack Reporter")
struct CrashlyticsDubPackReporterTests {

    @Test func forwardsBreadcrumbs() {
        let sink = RecordingSink()

        CrashlyticsDubPackReporter(sink: sink).log("dub_pack.import staged")

        #expect(sink.logs == ["dub_pack.import staged"])
    }

    /// Each kind gets its own code in one domain, so Crashlytics groups a kind as one issue.
    @Test func recordsAReportAsANonFatalGroupedByItsKind() throws {
        let sink = RecordingSink()
        let report = DubPackIssueReport(
            kind: .missingStills,
            reason: "2 of 10 entries had no still",
            keys: ["pack_title": .string("Scene"), "missing_count": .int(2), "ratio": .double(0.2), "partial_kept": .bool(true)]
        )

        CrashlyticsDubPackReporter(sink: sink).record(report)

        let record = try #require(sink.records.first)
        #expect(record.error.domain == CrashlyticsDubPackReporter.errorDomain)
        #expect(record.error.code == DubPackIssueReport.Kind.missingStills.code)
        #expect(record.error.localizedDescription == "2 of 10 entries had no still")
        #expect(record.context == "dub_pack.missing_stills")
        #expect(record.keys["pack_title"] as? String == "Scene")
        #expect(record.keys["missing_count"] as? Int == 2)
        #expect(record.keys["ratio"] as? Double == 0.2)
        #expect(record.keys["partial_kept"] as? Bool == true)
    }

    /// End to end: a pack that loses a line on the way in produces exactly one non-fatal, and
    /// a library re-read of the same folder produces none.
    @Test func aPackThatDropsALineIsReportedOnceAndOnlyOnImport() async throws {
        let sink = RecordingSink()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dubreport-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source/Broken Scene", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "[data]\ntitle=\"Broken Scene\"\n".write(to: source.appendingPathComponent("_pack_info.ini"), atomically: true, encoding: .utf8)
        try "[data]\ndub_timestamps=[0]\nimage=\"001_A.jpg\"\n".write(to: source.appendingPathComponent("001_A.txt"), atomically: true, encoding: .utf8)
        try "[data]\ndub_timestamps=[2]\n".write(to: source.appendingPathComponent("002_A.txt"), atomically: true, encoding: .utf8)
        try Data([0xFF, 0xD8, 0xFF]).write(to: source.appendingPathComponent("001_A.jpg"))
        try writeSilence(to: source.appendingPathComponent("001_A.wav"))

        let installer = DubPackInstaller(
            libraryDirectory: root.appendingPathComponent("library"),
            reporter: CrashlyticsDubPackReporter(sink: sink)
        )
        let installed = try await installer.install(from: source)

        #expect(sink.records.map(\.context) == ["dub_pack.dropped_lines"])
        #expect(sink.records.first?.keys["sample"] as? String == "002_A.txt (missing_audio)")

        _ = try await DubPackReader().read(at: installed.directory)
        #expect(sink.records.count == 1, "reading an installed pack never reports")
    }

    /// A second of silence. In its own function so the file is closed, and its header written,
    /// before anything reads it.
    private func writeSilence(to url: URL) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000)!
        buffer.frameLength = 48_000
        try file.write(from: buffer)
    }
}
