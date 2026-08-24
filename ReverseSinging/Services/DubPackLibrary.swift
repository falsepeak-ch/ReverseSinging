//
//  DubPackLibrary.swift
//  ReverseSinging
//
//  The set of dub packs installed on this device
//

import Foundation
import Combine

@MainActor
final class DubPackLibrary: ObservableObject {

    @Published private(set) var packs: [DubPack] = []
    @Published private(set) var isImporting = false
    @Published var importProgress: Double = 0
    /// What the import is currently doing, for the progress overlay.
    @Published private(set) var importMessage: String = Strings.Dub.importing
    @Published var errorMessage: String?

    private let importer = DubPackImporter.shared

    init() {
        reload()
    }

    // MARK: - Loading

    /// Rebuilds the list from disk. Packs are the source of truth — there is no separate
    /// index to fall out of sync with what's actually installed.
    func reload() {
        let root = AudioFileManager.shared.dubPacksDirectory()

        let directories = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        packs = directories
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false }
            .compactMap { load(from: $0) }
            .sorted { $0.importedAt > $1.importedAt }
    }

    private func load(from directory: URL) -> DubPack? {
        let folderName = directory.lastPathComponent

        // The cached manifest is the fast path; a pack copied in by hand (or written by an
        // older build) still loads, and gets a manifest written for next time.
        if let cached = importer.readManifest(at: directory),
           cached.folderName == folderName,
           !manifestIsMissingAVideoOnDisk(cached, in: directory) {
            return cached
        }

        guard let parsed = try? DubPackParser.parsePack(at: directory, folderName: folderName) else {
            return nil
        }

        try? importer.writeManifest(parsed, to: directory)
        return parsed
    }

    /// True when the manifest predates video support but the pack has a playable video sitting
    /// in its folder.
    ///
    /// Manifests written before the video field existed decode with `videoFile == nil`, and
    /// because the cache is the fast path that stale answer would win on every launch — the
    /// scene would silently keep showing stills with the video right there on disk. Re-parsing
    /// costs one directory scan, and only for packs in that state.
    func manifestIsMissingAVideoOnDisk(_ pack: DubPack, in directory: URL) -> Bool {
        guard pack.videoFile == nil else { return false }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents.contains {
            $0.deletingPathExtension().lastPathComponent == DubPackParser.videoPrefix
                && DubPackParser.hasReadableVideoTrack(at: $0)
        }
    }

    /// Weighted by how long each stage actually takes — a Theora scene can be 150 MB, so
    /// conversion owns most of the bar.
    private static func overallProgress(stage: DubImportStage, value: Double) -> Double {
        switch stage {
        case .copying: return value * 0.15
        case .convertingVideo: return 0.15 + value * 0.75
        case .reading: return 0.90 + value * 0.10
        }
    }

    // MARK: - Import

    func importPack(from url: URL) async {
        isImporting = true
        importProgress = 0
        importMessage = Strings.Dub.importing
        defer { isImporting = false }

        do {
            let pack = try await importer.importPack(from: url) { [weak self] stage, value in
                Task { @MainActor in
                    self?.importMessage = stage.message
                    self?.importProgress = Self.overallProgress(stage: stage, value: value)
                }
            }

            reload()
            HapticManager.shared.success()
            AnalyticsManager.shared.trackDubPackImported(title: pack.title, lineCount: pack.lines.count)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }

    // MARK: - Deletion

    func delete(_ pack: DubPack) {
        try? AudioFileManager.shared.deleteDubPack(folderName: pack.folderName, packID: pack.id)
        reload()
        HapticManager.shared.light()
    }

    // MARK: - Takes

    /// The line slugs the user has already recorded a take for.
    nonisolated func recordedLineSlugs(for pack: DubPack) -> Set<String> {
        let directory = AudioFileManager.shared.dubTakesDirectory(packID: pack.id)

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return Set(
            contents
                .filter { $0.pathExtension.lowercased() == "caf" }
                .map { $0.deletingPathExtension().lastPathComponent }
        )
    }

    func recordedCount(for pack: DubPack) -> Int {
        let recorded = recordedLineSlugs(for: pack)
        return pack.lines.filter { recorded.contains($0.slug) }.count
    }
}
