//
//  DubPackLibrary.swift
//  ReverseSinging
//
//  The set of dub packs installed on this device
//

import AVFoundation
import Combine
import DubPackKit
import Foundation

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
    /// appear, and reported through the same progress overlay an ordinary import uses, the
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

    /// Rebuilds the list from disk. Packs are the source of truth. There is no separate
    /// index to fall out of sync with what's actually installed.
    ///
    /// Fire-and-forget, so callers stay synchronous. `packs` is only replaced once the new
    /// list is ready, so a reload never blanks the screen it is refreshing.
    func reload() {
        reloadTask?.cancel()
        reloadTask = Task { await reloadNow() }
    }

    /// The same refresh, awaited, used where the next step depends on the result.
    func reloadNow() async {
        packs = await Self.loadAll()
    }

    /// Off the main actor: a re-read measures every reference recording in the pack, which is
    /// exactly the work that must not happen on the way to drawing a frame.
    @concurrent
    private nonisolated static func loadAll() async -> [DubPack] {
        let root = AudioFileManager.shared.dubPacksDirectory()

        // Hidden folders are installs still in progress, or ones a crash left behind.
        let directories = ((try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false }

        var packs: [DubPack] = []
        for directory in directories {
            if let pack = await load(from: directory) {
                packs.append(pack)
            }
        }
        return packs.sorted { $0.importedAt > $1.importedAt }
    }

    /// Loads one installed pack: from its manifest when that is current, else by reading the
    /// folder again. Nil when the folder does not read as a pack.
    nonisolated static func load(from directory: URL) async -> DubPack? {
        let folderName = directory.lastPathComponent
        let cached = DubPackManifest.read(at: directory)

        // The cached manifest is the fast path; a pack copied in by hand, or written by an
        // older build, still loads, and gets a manifest written for next time.
        if let cached, cached.folderName == folderName, await !manifestIsStale(cached, in: directory) {
            return cached
        }

        do {
            // The identity, date and fallback title carry over from the manifest being replaced:
            // takes are stored under the pack's id, and a fresh one would orphan every take
            // recorded; a pack without pack info would otherwise lose the title it was installed under.
            let reading = try await DubPackReader().read(at: directory, fallbackTitle: cached?.title)
            let pack = DubPack(
                parsed: reading.pack,
                directory: directory,
                id: cached?.id ?? UUID(),
                importedAt: cached?.importedAt ?? Date()
            )
            try? DubPackManifest.write(pack, to: directory)
            return pack
        } catch {
            // A pack that is installed and will not load is the quietest failure in the app:
            // the folder is on disk, the user imported it and performed it, and it is simply
            // not on the shelf any more. There is no alert for this, because nobody asked
            // for anything. Reported per launch while it lasts, which is the point. A pack
            // that stops loading after an OS update is a regression we would otherwise only
            // hear about as "my scenes disappeared".
            CrashReporter.shared.record(
                error,
                context: "dub_pack.load",
                keys: ["folder_name": folderName]
            )
            return nil
        }
    }

    /// True when the cached manifest is missing something a re-read would find.
    ///
    /// The cache is the fast path, so anything a manifest predates would otherwise win on
    /// every launch and never be corrected:
    ///
    /// - **Unmeasured speech windows.** Lines without one fall back to their whole chunk,
    ///   which puts captions up to two seconds early and drops takes at the chunk's start
    ///   rather than where the character speaks.
    /// - **Missing provenance.** Manifests written before the attribution fields existed
    ///   decode with `source == nil`, and the starter packs. The only ones that carry
    ///   someone else's work, are precisely the packs already installed on every device
    ///   that has ever opened dub mode. Without this they would keep printing no credit.
    /// - **A video on disk the manifest doesn't name.** Manifests written before the video
    ///   field existed decode with `videoFile == nil`, and the scene would keep showing
    ///   stills with the video sitting right there in the folder.
    ///
    /// Re-reading costs one pass over the pack, and only for packs in that state.
    nonisolated static func manifestIsStale(_ pack: DubPack, in directory: URL) async -> Bool {
        guard pack.hasMeasuredSpeech else { return true }
        if manifestIsMissingAttributionOnDisk(pack, in: directory) { return true }
        return await manifestIsMissingAVideoOnDisk(pack, in: directory)
    }

    /// True when the pack's own info names a source the manifest doesn't carry.
    ///
    /// Deliberately keyed on the file rather than on a version stamp: the question is only
    /// ever "is there credit here that isn't being shown", and the pack folder is where the
    /// answer is. A pack that genuinely has no provenance answers no on every launch, at the
    /// cost of one small read.
    nonisolated static func manifestIsMissingAttributionOnDisk(_ pack: DubPack, in directory: URL) -> Bool {
        guard pack.source == nil else { return false }
        return DubPackReader().provenance(in: directory).source != nil
    }

    nonisolated static func manifestIsMissingAVideoOnDisk(_ pack: DubPack, in directory: URL) async -> Bool {
        guard pack.videoFile == nil else { return false }
        return await DubPackReader().playableSceneVideo(in: directory) != nil
    }

    /// How far a scene video may fall short of the pack's own timeline before it is treated
    /// as damaged rather than merely rounded.
    ///
    /// A sound conversion lands within a frame or two. The real packs measure 0.02 s and
    /// 0.06 s out. A pack converted by the build that dropped duplicate frames is short by the
    /// whole run of them, which on a two-minute scene came to over five seconds.
    nonisolated static let truncatedVideoTolerance: TimeInterval = 0.25

    /// True when a pack's video ends materially before the scene's audio does.
    ///
    /// Builds before `TheoraTranscoder` learned to keep duplicate frames dropped every one of
    /// them, so the picture ran progressively ahead of the voices, over five seconds by the
    /// end of one real scene. The Theora original is deleted once converted, so an affected
    /// pack cannot be repaired in place; it has to be imported again.
    ///
    /// Measured rather than stamped with a version, because the damage itself is what can be
    /// seen: the video is short by exactly the frames that went missing, whatever build did
    /// it. A pack that ships its video as MP4 and never went through the transcoder is
    /// correct by construction and reads well inside the tolerance.
    nonisolated static func sceneVideoIsTruncated(_ pack: DubPack) -> Bool {
        guard pack.duration > 0, let videoURL = pack.videoURL,
              FileManager.default.fileExists(atPath: videoURL.path) else { return false }

        let video = CMTimeGetSeconds(AVURLAsset(url: videoURL).duration)
        guard video.isFinite, video > 0 else { return false }

        return pack.duration - video > truncatedVideoTolerance
    }

    /// Weighted by how long each stage actually takes. A Theora scene can be 150 MB, so
    /// conversion owns most of the bar.
    private static func overallProgress(_ progress: DubPackInstallProgress) -> Double {
        switch progress.stage {
        case .copying: progress.fraction * 0.15
        case .convertingVideo: 0.15 + progress.fraction * 0.75
        case .reading: 0.90 + progress.fraction * 0.10
        }
    }

    // MARK: - Import

    func importPack(from url: URL) async {
        isImporting = true
        importProgress = 0
        importMessage = Strings.Dub.importing
        defer { isImporting = false }

        let sourceExtension = url.pathExtension.lowercased()

        // Before any work, so an import the user abandons partway through a long video
        // conversion is still counted as an attempt rather than vanishing entirely.
        AnalyticsManager.shared.trackDubPackImportStarted(
            sourceName: url.lastPathComponent,
            sourceExtension: sourceExtension
        )

        do {
            let pack = try await DubPackImporter.shared.importPack(from: url) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.importMessage = progress.stage.message
                    self?.importProgress = Self.overallProgress(progress)
                }
            }

            await reloadNow()
            HapticManager.shared.success()
            AnalyticsManager.shared.trackDubPackImported(
                title: pack.title,
                authors: pack.authors,
                sourceName: url.lastPathComponent,
                lineCount: pack.lines.count,
                characterCount: Set(pack.lines.map(\.character)).count,
                duration: pack.duration,
                hasVideo: pack.videoFile != nil,
                hasBackingTrack: pack.backingTrackFile != nil,
                hasAttribution: pack.hasAttribution,
                source: pack.source,
                sourceURL: pack.sourceURL
            )
        } catch {
            errorMessage = DubPackImportMessage.text(for: error)
            HapticManager.shared.error()

            // The non-fatal for this failure has already been sent by DubPackKit, together with
            // the issues that led to it. The event is what makes failing packs countable next
            // to the ones that work.
            AnalyticsManager.shared.trackDubPackImportFailed(
                sourceName: url.lastPathComponent,
                sourceExtension: sourceExtension,
                reason: (error as? DubPackImportError)?.telemetryCode ?? String(describing: error)
            )
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
