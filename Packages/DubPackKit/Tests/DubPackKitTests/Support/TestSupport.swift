//
//  TestSupport.swift
//  DubPackKitTests
//

import AVFoundation
import Foundation
import Testing
@testable import DubPackKit

// MARK: - Fixtures

/// Files in `Tests/DubPackKitTests/Fixtures`. See the README there for how each was made.
enum Fixtures {
    static func url(_ name: String) throws -> URL {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
        return try #require(url, "missing fixture \(name)")
    }
}

// MARK: - Temporary Directory

/// A fresh directory under the system temporary folder. Remove it with `defer { temp.remove() }`.
struct TemporaryDirectory {
    let url: URL

    init(_ label: String = "dubpackkit") throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func appending(_ component: String) -> URL {
        url.appendingPathComponent(component)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Media Probe

/// The real probe, with chosen files declared undecodable or given a chosen video length.
struct StubMediaProbe: MediaProbe {
    var undecodable: Set<String> = []
    var videoDurations: [String: TimeInterval] = [:]

    private let real = AVFoundationMediaProbe()

    func audioDuration(of url: URL) -> TimeInterval? {
        undecodable.contains(url.lastPathComponent) ? nil : real.audioDuration(of: url)
    }

    func videoDuration(of url: URL) async -> TimeInterval? {
        if let forced = videoDurations[url.lastPathComponent] { return forced }
        return undecodable.contains(url.lastPathComponent) ? nil : await real.videoDuration(of: url)
    }
}

// MARK: - Issue Reporter

/// Keeps everything an install reports, in order.
final class RecordingIssueReporter: DubPackIssueReporter, @unchecked Sendable {
    private let lock = NSLock()
    private var storedBreadcrumbs: [String] = []
    private var storedReports: [DubPackIssueReport] = []

    func log(_ breadcrumb: String) {
        lock.withLock { storedBreadcrumbs.append(breadcrumb) }
    }

    func record(_ report: DubPackIssueReport) {
        lock.withLock { storedReports.append(report) }
    }

    var breadcrumbs: [String] { lock.withLock { storedBreadcrumbs } }
    var reports: [DubPackIssueReport] { lock.withLock { storedReports } }
    var kinds: [DubPackIssueReport.Kind] { reports.map(\.kind) }

    func report(_ kind: DubPackIssueReport.Kind) -> DubPackIssueReport? {
        reports.first { $0.kind == kind }
    }
}

// MARK: - Installer

extension DubPackInstaller {
    /// An installer over `library`, with the probe and reporter a test chooses.
    static func testing(
        library: URL,
        reporter: (any DubPackIssueReporter)? = nil,
        probe: any MediaProbe = AVFoundationMediaProbe(),
        ignoredFileNames: Set<String> = []
    ) -> DubPackInstaller {
        DubPackInstaller(
            libraryDirectory: library,
            ignoredFileNames: ignoredFileNames,
            reporter: reporter,
            probe: probe,
            temporaryDirectory: FileManager.default.temporaryDirectory
        )
    }
}

extension DubPackReader {
    static func testing(probe: any MediaProbe = AVFoundationMediaProbe()) -> DubPackReader {
        DubPackReader(probe: probe)
    }
}
