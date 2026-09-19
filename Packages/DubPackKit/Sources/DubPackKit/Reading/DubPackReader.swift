//
//  DubPackReader.swift
//  DubPackKit
//

public import Foundation

/// Reads a pack folder that is already on disk.
///
/// Use it for packs that are installed: re-reading one whose cached description is out of
/// date, or asking a folder a single question. Bringing a pack in from elsewhere is
/// `DubPackInstaller`'s job, which uses this reader and also reports what it finds.
///
/// A reader never reports anything. That is deliberate: an installed pack is re-read on some
/// later launch, and reporting there would repeat every non-fatal its import already sent.
public struct DubPackReader: Sendable {

    let probe: any MediaProbe

    public init() {
        self.init(probe: AVFoundationMediaProbe())
    }

    init(probe: any MediaProbe) {
        self.probe = probe
    }

    // MARK: - Reading

    /// Reads the pack at `directory`, dropping and degrading what it has to rather than
    /// failing the whole pack.
    ///
    /// - Parameter fallbackTitle: the title when the pack info names none: for an installed pack,
    ///   the title it was installed under. Defaults to the folder's name.
    /// - Throws: `sourceMissing` when the folder cannot be listed, `noPackFound` when nothing
    ///   in it looks like a pack, `noLines` when not one entry became a line.
    @concurrent
    public func read(at directory: URL, fallbackTitle: String? = nil) async throws(DubPackImportError) -> DubPackReading {
        guard let folder = PackDirectory(url: directory) else { throw .sourceMissing }

        let entries = folder.entryCandidates
        guard folder.packInfoFile != nil || !entries.isEmpty else { throw .noPackFound }

        var issues: [DubPackIssue] = []
        let info = packInfo(in: folder, issues: &issues)

        // Resolved before the lines, so a line with no still of its own has one to borrow.
        let namedIcon = info.string(PackFormat.Keys.icon)
        let icon = namedIcon.flatMap(folder.file(named:)) ?? folder.conventionalIcon
        if let namedIcon, folder.file(named: namedIcon) == nil {
            issues.append(.missingIcon(file: namedIcon))
        }
        let anyImage = folder.files(extensions: PackFormat.Files.imageExtensions).first

        let entryReader = LineEntryReader(directory: folder, probe: probe)
        var lines: [ParsedLine] = []
        var candidateLineCount = 0
        var notes: [String] = []

        for (offset, entry) in entries.enumerated() {
            let fallbackStill = lines.last?.imageFile ?? icon?.name ?? anyImage?.name

            switch entryReader.read(entry, position: offset + 1, fallbackStill: fallbackStill) {
            case .line(let line, let lineIssues):
                candidateLineCount += 1
                lines.append(line)
                issues += lineIssues
            case .dropped(let reason):
                candidateLineCount += 1
                issues.append(.droppedLine(file: entry.name, reason: reason))
            case .notAnEntry:
                notes.append(entry.name)
            }
        }

        if folder.packInfoFile == nil {
            issues.append(.missingPackInfo(otherTextFiles: notes))
        }
        if candidateLineCount == 0 {
            issues.append(.noLineEntries(fileTypes: folder.fileTypeCounts))
        }

        guard !lines.isEmpty else { throw .noLines(issues: issues) }
        lines.sort { ($0.startTime, $0.index) < ($1.startTime, $1.index) }

        let claimedAudio = Set(lines.map { PackDirectory.key($0.referenceAudioFile) })
        let backingTrack = playableBackingTrack(in: folder, claimedNames: claimedAudio, issues: &issues)
        let video = await playableVideo(in: folder, issues: &issues)

        let pack = ParsedPack(
            title: info.string(PackFormat.Keys.title) ?? fallbackTitle ?? directory.lastPathComponent,
            authors: info.list(PackFormat.Keys.authors),
            iconFile: icon?.name ?? lines.lazy.compactMap(\.imageFile).first,
            backingTrackFile: backingTrack?.file.name,
            videoFile: video?.file.name,
            lines: lines,
            duration: backingTrack?.duration ?? video?.duration ?? lines.map(\.endTime).max() ?? 0,
            provenance: PackProvenance(fields: info)
        )

        return DubPackReading(pack: pack, issues: issues, candidateLineCount: candidateLineCount)
    }

    /// The pack's provenance alone: one small read, for checking whether a cached description
    /// is missing credit the folder carries.
    public func provenance(in directory: URL) -> PackProvenance {
        guard let folder = PackDirectory(url: directory),
              let file = folder.packInfoFile,
              let text = PackTextDecoder.read(at: file.url) else {
            return .unknown
        }
        return PackProvenance(fields: PackFields(parsing: text))
    }

    /// The name of the scene video in `directory`, when there is one AVFoundation can play.
    @concurrent
    public func playableSceneVideo(in directory: URL) async -> String? {
        guard let folder = PackDirectory(url: directory),
              case .found(let file) = folder.sceneVideo,
              await probe.videoDuration(of: file.url) != nil else {
            return nil
        }
        return file.name
    }

    // MARK: - Pack Files

    private func packInfo(in folder: PackDirectory, issues: inout [DubPackIssue]) -> PackFields {
        guard let file = folder.packInfoFile else { return PackFields() }
        guard let text = PackTextDecoder.read(at: file.url) else {
            issues.append(.unreadablePackInfo(file: file.name))
            return PackFields()
        }
        return PackFields(parsing: text)
    }

    private func playableBackingTrack(
        in folder: PackDirectory,
        claimedNames: Set<String>,
        issues: inout [DubPackIssue]
    ) -> (file: PackFile, duration: TimeInterval)? {
        switch folder.backingTrack(claimedNames: claimedNames) {
        case .notFound:
            return nil
        case .ambiguous(let candidates):
            issues.append(.ambiguousBackingTrack(candidates: candidates.map(\.name)))
            return nil
        case .found(let file):
            // Only a track AVFoundation reads counts. An Ogg Vorbis bed would otherwise be
            // recorded here and play as silence everywhere else.
            guard let duration = probe.audioDuration(of: file.url) else {
                issues.append(.unplayableBackingTrack(file: file.name))
                return nil
            }
            return (file, duration)
        }
    }

    private func playableVideo(
        in folder: PackDirectory,
        issues: inout [DubPackIssue]
    ) async -> (file: PackFile, duration: TimeInterval)? {
        switch folder.sceneVideo {
        case .notFound:
            return nil
        case .ambiguous(let candidates):
            issues.append(.ambiguousSceneVideo(candidates: candidates.map(\.name)))
            return nil
        case .found(let file):
            // A dub_video.ogv that was never converted reads as a file and shows as a black
            // rectangle, so only a video with a track AVFoundation can decode counts.
            guard let duration = await probe.videoDuration(of: file.url) else {
                issues.append(.unplayableSceneVideo(file: file.name))
                return nil
            }
            return (file, duration)
        }
    }
}

/// What `DubPackReader.read(at:)` found.
public struct DubPackReading: Sendable, Hashable {
    public let pack: ParsedPack
    /// Everything the reader dropped or had to work around, in the order it met them.
    public let issues: [DubPackIssue]
    /// How many entries the pack offered, dropped ones included.
    public let candidateLineCount: Int
}
