//
//  DebugImportRun.swift
//  ReverseSinging
//
//  Imports a folder of packs at launch and prints a verdict per pack. Debug builds only.
//

#if DEBUG

import DubPackKit
import Foundation

/// Runs every pack in a folder through the real import, the way a user would bring them in,
/// and says what came of each one.
///
/// Driven from the launch arguments, for the Simulator, which can read the Mac's disk:
///
///     -importPacksFrom /Users/me/DubPacks
///
/// Each item in that folder (a pack folder, a `.zip`, a `.7z`, or something that is none of
/// those) is imported in turn through `DubPackLibrary`, so starter packs, manifests, repair
/// and reporting all happen exactly as in the app. One line per pack goes to the console, and
/// the whole run is written as `ImportReport.json` in the app's Documents folder.
///
/// Optional: `-clearPacksFirst YES` empties the library before the run, so a re-import of the
/// same folder starts from nothing.
enum DebugImportRun {

    /// Writes a line to standard error, which is never buffered: `print` goes to standard
    /// output, and when `simctl launch --console` is redirected to a file that is block
    /// buffered and shows nothing until the app exits.
    private static func emit(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    static var folder: URL? {
        UserDefaults.standard.string(forKey: "importPacksFrom")
            .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
    }

    static var isRequested: Bool { folder != nil }

    private static var clearsPacksFirst: Bool {
        UserDefaults.standard.bool(forKey: "clearPacksFirst")
    }

    struct Verdict: Codable {
        let source: String
        let outcome: String
        var title: String?
        var lines: Int?
        var backingTrack: String?
        var video: String?
        var error: String?
        let seconds: Double
    }

    /// Runs when the launch arguments ask for it, over a library of its own. Called once, from
    /// the root view, so the run happens whatever screen the app opens on.
    @MainActor
    static func runIfRequested() async {
        guard isRequested else { return }
        let library = DubPackLibrary()
        await library.waitForReloadForTesting()
        await run(using: library)
    }

    /// Imports everything in `folder` and reports. Returns once the last pack is done.
    @MainActor
    static func run(using library: DubPackLibrary) async {
        guard let folder else { return }
        let contents = ((try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        emit("🧪 IMPORT RUN: \(contents.count) items in \(folder.path)")

        if clearsPacksFirst {
            for pack in library.packs { library.delete(pack) }
            await library.reloadNow()
            emit("🧪 IMPORT RUN: library cleared")
        }

        var verdicts: [Verdict] = []
        for item in contents {
            let started = Date()
            let before = Set(library.packs.map(\.id))
            library.errorMessage = nil

            await library.importPack(from: item)

            let elapsed = Date().timeIntervalSince(started)
            let name = item.lastPathComponent
            if let message = library.errorMessage {
                emit("❌ IMPORT \(name) → \(message) (\(String(format: "%.1f", elapsed))s)")
                verdicts.append(Verdict(source: name, outcome: "failed", error: message, seconds: elapsed))
                continue
            }

            // The pack that appeared, or the one replaced in place under the same folder name.
            let folderName = item.hasDirectoryPath ? name : (name as NSString).deletingPathExtension
            let pack = library.packs.first { !before.contains($0.id) }
                ?? library.packs.first { $0.folderName == folderName }
            guard let pack else {
                emit("⚠️ IMPORT \(name) → finished but no pack found on the shelf")
                verdicts.append(Verdict(source: name, outcome: "missing", seconds: elapsed))
                continue
            }

            emit("""
            ✅ IMPORT \(name) → "\(pack.title)" \(pack.lines.count) lines, \
            backing: \(pack.backingTrackFile ?? "none"), video: \(pack.videoFile ?? "none") \
            (\(String(format: "%.1f", elapsed))s)
            """)
            verdicts.append(Verdict(
                source: name, outcome: "installed", title: pack.title, lines: pack.lines.count,
                backingTrack: pack.backingTrackFile, video: pack.videoFile, seconds: elapsed
            ))
        }

        let installed = verdicts.filter { $0.outcome == "installed" }.count
        emit("🧪 IMPORT RUN DONE: \(installed)/\(verdicts.count) installed")
        writeReport(verdicts)
    }

    private static func writeReport(_ verdicts: [Verdict]) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("ImportReport.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(verdicts) {
            try? data.write(to: url)
            emit("🧪 IMPORT RUN report: \(url.path)")
        }
    }
}

#endif
