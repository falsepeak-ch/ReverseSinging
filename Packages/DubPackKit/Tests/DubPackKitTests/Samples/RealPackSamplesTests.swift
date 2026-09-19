//
//  RealPackSamplesTests.swift
//  DubPackKitTests
//

import Foundation
import Testing
@testable import DubPackKit

/// Installs every real community pack in a folder, and checks each came in without losing content.
///
/// Point `DUB_PACK_SAMPLES` at a folder of packs (folders, `.zip`s and `.7z`s, mixed). Skipped
/// when the variable is unset, so it costs nothing otherwise. The packs stay out of the
/// repository: they are cut from other people's films.
///
///     DUB_PACK_SAMPLES=~/DubPackSamples swift test --filter RealPackSamplesTests
@Suite("Real pack samples")
struct RealPackSamplesTests {

    static var samples: [URL] {
        guard let root = ProcessInfo.processInfo.environment["DUB_PACK_SAMPLES"], !root.isEmpty else { return [] }
        let folder = URL(fileURLWithPath: (root as NSString).expandingTildeInPath)
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    @Test(.enabled(if: !samples.isEmpty, "set DUB_PACK_SAMPLES to a folder of packs"), arguments: samples)
    func everySampleInstallsWithoutLosingContent(sample: URL) async throws {
        let temp = try TemporaryDirectory("dubsamples")
        defer { temp.remove() }

        let started = Date()
        let installed = try await DubPackInstaller(libraryDirectory: temp.url).install(from: sample)
        let pack = installed.pack

        print("""
        📦 \(sample.lastPathComponent): "\(pack.title)" by \(pack.authors.joined(separator: ", ")) \
        — \(pack.lines.count) lines, \(Set(pack.lines.map(\.character)).count) characters, \
        \(String(format: "%.1f", pack.duration))s, backing: \(pack.backingTrackFile ?? "none"), \
        video: \(pack.videoFile ?? "none"), issues: \(installed.issues), \
        in \(String(format: "%.1f", Date().timeIntervalSince(started)))s
        """)

        let losses = installed.issues.filter { !Self.keepsAllContent($0) }
        #expect(losses.isEmpty, "\(losses)")
        #expect(!pack.lines.isEmpty)
        #expect(pack.backingTrackFile != nil)
        #expect(pack.videoFile != nil)
        #expect(pack.duration > 0)
        #expect(pack.lines.allSatisfy { $0.duration > 0 })
    }

    /// Issues that say a pack arrived differently rather than with less: no pack info to title it,
    /// or a cut-off archive whose only casualty was the tail of a recording that still plays.
    private static func keepsAllContent(_ issue: DubPackIssue) -> Bool {
        switch issue {
        case .missingPackInfo:
            true
        case .archiveRecovered(let truncatedEntry, let partialKept, let damagedEntries):
            damagedEntries == 0 && (truncatedEntry == nil || partialKept)
        default:
            false
        }
    }
}
