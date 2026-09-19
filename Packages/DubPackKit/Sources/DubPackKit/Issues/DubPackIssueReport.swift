//
//  DubPackIssueReport.swift
//  DubPackKit
//

/// One non-fatal's worth of what an install found: every issue of one kind for one pack, or one
/// failed install.
///
/// Grouped by kind rather than sent one per issue, so a crash reporter clusters reports by the
/// thing that has to be fixed, and a pack with sixty broken entries sends one report, not sixty.
/// `context` and `kind.code` are stable and safe to group on. Keys carry names inside the pack,
/// counts and the pack's own title, never anything a line says.
public struct DubPackIssueReport: Sendable, Hashable {

    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case droppedLines = "dropped_lines"
        case noLineEntries = "no_line_entries"
        case extraTimestamps = "extra_timestamps"
        case missingStills = "missing_stills"
        case missingIcon = "missing_icon"
        case missingPackInfo = "missing_pack_info"
        case unreadablePackInfo = "unreadable_pack_info"
        case ambiguousBackingTrack = "ambiguous_backing_track"
        case unplayableBackingTrack = "unplayable_backing_track"
        case ambiguousVideo = "ambiguous_video"
        case unplayableVideo = "unplayable_video"
        case videoTranscode = "video_transcode"
        case recoveredArchive = "recovered_archive"
        case skippedArchiveEntries = "skipped_archive_entries"
        case importFailed = "import"

        /// `dub_pack.<kind>`, the name existing crash reports already group under.
        public var context: String { "dub_pack.\(rawValue)" }

        /// A number per kind, for error codes. Never renumber: it is what groups reports.
        public var code: Int {
            switch self {
            case .droppedLines: 1
            case .extraTimestamps: 2
            case .missingStills: 3
            case .missingIcon: 4
            case .missingPackInfo: 5
            case .unreadablePackInfo: 6
            case .ambiguousBackingTrack: 7
            case .unplayableBackingTrack: 8
            case .ambiguousVideo: 9
            case .unplayableVideo: 10
            case .videoTranscode: 11
            case .skippedArchiveEntries: 12
            case .noLineEntries: 13
            case .recoveredArchive: 14
            case .importFailed: 100
            }
        }
    }

    public enum Value: Sendable, Hashable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
    }

    public let kind: Kind
    /// A one-line English summary, e.g. `3 of 60 entries dropped (missing_audio)`.
    public let reason: String
    public let keys: [String: Value]

    public var context: String { kind.context }

    public init(kind: Kind, reason: String, keys: [String: Value]) {
        self.kind = kind
        self.reason = reason
        self.keys = keys
    }
}

// MARK: - Building Reports

extension DubPackIssueReport {

    /// At most this many file names go into a `sample` key.
    static let sampleLimit = 5
    static let sampleItemLength = 64
    static let titleLength = 100
    static let detailLength = 200
    /// At most this many extensions go into a `file_types` key.
    static let fileTypeLimit = 10

    /// One report per kind present in `issues`, in `Kind` order.
    static func reports(
        for issues: [DubPackIssue],
        packTitle: String,
        candidateLineCount: Int,
        keptLineCount: Int
    ) -> [DubPackIssueReport] {
        let grouped = Dictionary(grouping: issues, by: \.kind)
        let context = PackContext(title: packTitle, candidateLineCount: candidateLineCount, keptLineCount: keptLineCount)

        return Kind.allCases.compactMap { kind in
            grouped[kind].map { report(for: $0, kind: kind, context: context) }
        }
    }

    /// The report for an install that failed outright.
    static func importFailure(
        _ error: DubPackImportError,
        stage: DubPackInstallProgress.Stage,
        sourceExtension: String,
        packTitle: String
    ) -> DubPackIssueReport {
        var keys: [String: Value] = [
            "pack_title": .string(clip(packTitle, to: titleLength)),
            "failure": .string(error.telemetryCode),
            "stage": .string(stage.rawValue),
            "source_extension": .string(sourceExtension),
        ]
        if let detail = error.detail {
            keys["detail"] = .string(clip(detail, to: detailLength))
        }
        return DubPackIssueReport(kind: .importFailed, reason: "Import failed: \(error.telemetryCode)", keys: keys)
    }

    // MARK: - Per Kind

    private struct PackContext {
        let title: String
        let candidateLineCount: Int
        let keptLineCount: Int
    }

    private static func report(for group: [DubPackIssue], kind: Kind, context: PackContext) -> DubPackIssueReport {
        var keys: [String: Value] = ["pack_title": .string(clip(context.title, to: titleLength))]
        let reason: String

        switch kind {
        case .droppedLines:
            let dropped: [(file: String, reason: DroppedLineReason)] = group.compactMap {
                if case .droppedLine(let file, let reason) = $0 { (file, reason) } else { nil }
            }
            let reasons = Set(dropped.map(\.reason.rawValue)).sorted().joined(separator: ", ")
            keys["dropped_count"] = .int(dropped.count)
            keys["candidate_count"] = .int(context.candidateLineCount)
            keys["kept_count"] = .int(context.keptLineCount)
            keys["reasons"] = .string(reasons)
            keys["sample"] = sample(dropped.map { "\($0.file) (\($0.reason.rawValue))" })
            reason = "\(dropped.count) of \(context.candidateLineCount) entries dropped (\(reasons))"

        case .noLineEntries:
            guard case .noLineEntries(let fileTypes) = group[0] else { preconditionFailure("grouped by kind") }
            let fileCount = fileTypes.values.reduce(0, +)
            keys["file_count"] = .int(fileCount)
            keys["file_types"] = .string(describe(fileTypes))
            reason = "No line entries among \(fileCount) files"

        case .extraTimestamps:
            let files: [String] = group.compactMap {
                if case .extraTimestampsIgnored(let file, _) = $0 { file } else { nil }
            }
            keys["entry_count"] = .int(files.count)
            keys["sample"] = sample(files)
            reason = "\(files.count) entries have start times beyond the first"

        case .missingStills:
            let files: [String] = group.compactMap {
                if case .missingStill(let file, _) = $0 { file } else { nil }
            }
            keys["missing_count"] = .int(files.count)
            keys["candidate_count"] = .int(context.candidateLineCount)
            keys["sample"] = sample(files)
            reason = "\(files.count) of \(context.candidateLineCount) entries had no still"

        case .missingIcon:
            guard case .missingIcon(let file) = group[0] else { preconditionFailure("grouped by kind") }
            keys["file_extension"] = .string(fileExtension(of: file))
            reason = "The pack info names an icon that is not in the pack"

        case .missingPackInfo:
            guard case .missingPackInfo(let otherTextFiles) = group[0] else { preconditionFailure("grouped by kind") }
            keys["sample"] = sample(otherTextFiles)
            reason = "No pack info file under any accepted name"

        case .unreadablePackInfo:
            guard case .unreadablePackInfo(let file) = group[0] else { preconditionFailure("grouped by kind") }
            keys["file"] = .string(clip(file, to: sampleItemLength))
            reason = "The pack info is in no encoding the reader knows"

        case .ambiguousBackingTrack:
            guard case .ambiguousBackingTrack(let candidates) = group[0] else { preconditionFailure("grouped by kind") }
            keys["candidate_count"] = .int(candidates.count)
            keys["sample"] = sample(candidates)
            reason = "\(candidates.count) audio files could be the backing track"

        case .unplayableBackingTrack:
            guard case .unplayableBackingTrack(let file) = group[0] else { preconditionFailure("grouped by kind") }
            keys["file_extension"] = .string(fileExtension(of: file))
            reason = "AVFoundation cannot decode the backing track"

        case .ambiguousVideo:
            guard case .ambiguousSceneVideo(let candidates) = group[0] else { preconditionFailure("grouped by kind") }
            keys["candidate_count"] = .int(candidates.count)
            keys["sample"] = sample(candidates)
            reason = "\(candidates.count) videos could be the scene"

        case .unplayableVideo:
            guard case .unplayableSceneVideo(let file) = group[0] else { preconditionFailure("grouped by kind") }
            keys["file_extension"] = .string(fileExtension(of: file))
            reason = "No readable video track in the scene video"

        case .videoTranscode:
            guard case .videoConversionFailed(let file, let failure) = group[0] else { preconditionFailure("grouped by kind") }
            keys["source_extension"] = .string(fileExtension(of: file))
            keys["failure"] = .string(failure.telemetryName)
            if case .lengthMismatch(let expected, let actual) = failure {
                keys["expected_seconds"] = .double(expected)
                keys["actual_seconds"] = .double(actual)
            }
            if let detail = failure.detail {
                keys["detail"] = .string(clip(detail, to: detailLength))
            }
            reason = "The scene video could not be converted: \(failure.telemetryName)"

        case .recoveredArchive:
            guard case .archiveRecovered(let truncatedEntry, let partialKept, let damagedEntries) = group[0] else {
                preconditionFailure("grouped by kind")
            }
            keys["truncated_entry"] = .string(clip(truncatedEntry ?? "", to: sampleItemLength))
            keys["partial_kept"] = .bool(partialKept)
            keys["damaged_count"] = .int(damagedEntries)
            reason = truncatedEntry.map { "The archive ends partway through \($0)" }
                ?? "The archive's index was unusable; its entries were recovered one by one"

        case .skippedArchiveEntries:
            guard case .unsafeArchiveEntriesSkipped(let count) = group[0] else { preconditionFailure("grouped by kind") }
            keys["skipped_count"] = .int(count)
            reason = "\(count) archive entries pointed outside the pack"

        case .importFailed:
            preconditionFailure("an install failure is not a DubPackIssue")
        }

        return DubPackIssueReport(kind: kind, reason: reason, keys: keys)
    }

    // MARK: - Formatting

    private static func sample(_ items: [String]) -> Value {
        .string(items.prefix(sampleLimit).map { clip($0, to: sampleItemLength) }.joined(separator: ", "))
    }

    /// `ini: 38, jpg: 38, mp3: 38`: most common first, then alphabetical.
    private static func describe(_ fileTypes: [String: Int]) -> String {
        fileTypes
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(fileTypeLimit)
            .map { "\($0.key.isEmpty ? "none" : $0.key): \($0.value)" }
            .joined(separator: ", ")
    }

    private static func clip(_ text: String, to length: Int) -> String {
        text.count <= length ? text : String(text.prefix(length - 1)) + "…"
    }

    private static func fileExtension(of name: String) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return name[name.index(after: dot)...].lowercased()
    }
}

// MARK: - Issue Kinds

extension DubPackIssue {
    /// The report this issue is grouped into.
    public var kind: DubPackIssueReport.Kind {
        switch self {
        case .droppedLine: .droppedLines
        case .noLineEntries: .noLineEntries
        case .extraTimestampsIgnored: .extraTimestamps
        case .missingStill: .missingStills
        case .missingIcon: .missingIcon
        case .missingPackInfo: .missingPackInfo
        case .unreadablePackInfo: .unreadablePackInfo
        case .ambiguousBackingTrack: .ambiguousBackingTrack
        case .unplayableBackingTrack: .unplayableBackingTrack
        case .ambiguousSceneVideo: .ambiguousVideo
        case .unplayableSceneVideo: .unplayableVideo
        case .videoConversionFailed: .videoTranscode
        case .archiveRecovered: .recoveredArchive
        case .unsafeArchiveEntriesSkipped: .skippedArchiveEntries
        }
    }
}
