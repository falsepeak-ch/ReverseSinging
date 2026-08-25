//
//  DubPackLibrary.swift
//  ReverseSinging
//
//  The set of dub packs installed on this device
//

import AVFoundation
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

    private var reloadTask: Task<Void, Never>?

    init() {
        reloadTask = Task { [weak self] in
            await self?.installStarterPacksIfNeeded()
            await self?.reloadNow()
        }
    }

    // MARK: - Starter Packs

    /// Puts the bundled scenes on the shelf the first time the app runs.
    ///
    /// Ahead of the first `reloadNow`, so the library is never briefly empty before they
    /// appear, and reported through the same progress overlay an ordinary import uses — the
    /// work is the same work, and on a first launch it is the only thing happening.
    private func installStarterPacksIfNeeded() async {
        let pending = DubStarterPacks.pending
        guard !pending.isEmpty else { return }

        isImporting = true
        importMessage = Strings.Dub.installingStarterPacks
        importProgress = 0
        defer { isImporting = false }

        for (offset, name) in pending.enumerated() {
            await DubStarterPacks.install(name)
            importProgress = Double(offset + 1) / Double(pending.count)
        }
    }

    // MARK: - Loading

    /// Rebuilds the list from disk. Packs are the source of truth — there is no separate
    /// index to fall out of sync with what's actually installed.
    ///
    /// Fire-and-forget, so callers stay synchronous. `packs` is only replaced once the new
    /// list is ready, so a reload never blanks the screen it is refreshing.
    func reload() {
        reloadTask?.cancel()
        reloadTask = Task { await reloadNow() }
    }

    /// The same refresh, awaited — used where the next step depends on the result.
    func reloadNow() async {
        // Off the main actor: a re-parse reads every reference wav in the pack, which is
        // exactly the work that must not happen on the way to drawing a frame.
        packs = await Task.detached(priority: .userInitiated) { Self.loadAll() }.value
    }

    private nonisolated static func loadAll() -> [DubPack] {
        let root = AudioFileManager.shared.dubPacksDirectory()

        let directories = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return directories
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false }
            .compactMap { load(from: $0) }
            .sorted { $0.importedAt > $1.importedAt }
    }

    private nonisolated static func load(from directory: URL) -> DubPack? {
        let folderName = directory.lastPathComponent
        let importer = DubPackImporter.shared

        // The cached manifest is the fast path; a pack copied in by hand (or written by an
        // older build) still loads, and gets a manifest written for next time.
        if let cached = importer.readManifest(at: directory),
           cached.folderName == folderName,
           !manifestIsStale(cached, in: directory) {
            return cached
        }

        guard let parsed = try? DubPackParser.parsePack(at: directory, folderName: folderName) else {
            return nil
        }

        try? importer.writeManifest(parsed, to: directory)
        return parsed
    }

    /// True when the cached manifest is missing something a re-parse would find.
    ///
    /// The cache is the fast path, so anything a manifest predates would otherwise win on
    /// every launch and never be corrected. Two cases so far:
    ///
    /// - **A video on disk the manifest doesn't name.** Manifests written before the video
    ///   field existed decode with `videoFile == nil`, and the scene would keep showing
    ///   stills with the video sitting right there in the folder.
    /// - **Unmeasured speech windows.** Lines without one fall back to their whole chunk,
    ///   which puts captions up to two seconds early and drops takes at the chunk's start
    ///   rather than where the character speaks.
    ///
    /// Re-parsing costs one pass over the pack, and only for packs in that state.
    static nonisolated func manifestIsStale(_ pack: DubPack, in directory: URL) -> Bool {
        guard pack.hasMeasuredSpeech else { return true }
        return manifestIsMissingAVideoOnDisk(pack, in: directory)
    }

    /// How far a scene video may fall short of the pack's own timeline before it is treated
    /// as damaged rather than merely rounded.
    ///
    /// A sound conversion lands within a frame or two — the real packs measure 0.02 s and
    /// 0.06 s out. A pack converted by the build that dropped duplicate frames is short by the
    /// whole run of them, which on a two-minute scene came to over five seconds.
    static nonisolated let truncatedVideoTolerance: TimeInterval = 0.25

    /// True when a pack's video ends materially before the scene's audio does.
    ///
    /// Builds before `TheoraTranscoder` learned to keep duplicate frames dropped every one of
    /// them, so the picture ran progressively ahead of the voices — over five seconds by the
    /// end of one real scene. The Theora original is deleted once converted, so an affected
    /// pack cannot be repaired in place; it has to be imported again.
    ///
    /// Measured rather than stamped with a version, because the damage itself is what can be
    /// seen: the video is short by exactly the frames that went missing, whatever build did
    /// it. A pack that ships its video as MP4 and never went through the transcoder is
    /// correct by construction and reads well inside the tolerance.
    static nonisolated func sceneVideoIsTruncated(_ pack: DubPack) -> Bool {
        guard pack.duration > 0, let videoURL = pack.videoURL,
              FileManager.default.fileExists(atPath: videoURL.path) else { return false }

        let video = CMTimeGetSeconds(AVURLAsset(url: videoURL).duration)
        guard video.isFinite, video > 0 else { return false }

        return pack.duration - video > truncatedVideoTolerance
    }

    static nonisolated func manifestIsMissingAVideoOnDisk(_ pack: DubPack, in directory: URL) -> Bool {
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
            let pack = try await DubPackImporter.shared.importPack(from: url) { [weak self] stage, value in
                Task { @MainActor [weak self] in
                    self?.importMessage = stage.message
                    self?.importProgress = Self.overallProgress(stage: stage, value: value)
                }
            }

            await reloadNow()
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
