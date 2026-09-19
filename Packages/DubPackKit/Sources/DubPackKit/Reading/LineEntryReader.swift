//
//  LineEntryReader.swift
//  DubPackKit
//

import Foundation

/// Turns one line entry, `NNN_Character.txt`, and the files beside it into a `ParsedLine`.
///
/// Only what makes a line impossible to perform drops it: no start time, or no audio that
/// plays. Everything else degrades. A missing still borrows the previous line's, a missing
/// character name comes from the file name, a missing caption is empty.
struct LineEntryReader: Sendable {

    enum Outcome: Sendable, Equatable {
        case line(ParsedLine, issues: [DubPackIssue])
        case dropped(DroppedLineReason)
        /// A text file that is not an entry at all, such as a readme or the credits.
        case notAnEntry
    }

    let directory: PackDirectory
    let probe: any MediaProbe

    /// - Parameters:
    ///   - position: the entry's 1-based position in the folder, its index when its name has no number.
    ///   - fallbackStill: what to show when the entry's own still is missing.
    func read(_ entry: PackFile, position: Int, fallbackStill: String?) -> Outcome {
        let number = Int(entry.stem.prefix(while: \.isNumber))

        guard let text = PackTextDecoder.read(at: entry.url) else {
            // A numbered file that will not read is a lost line; an unreadable note is not.
            return number == nil ? .notAnEntry : .dropped(.unreadableText)
        }

        let fields = PackFields(parsing: text)
        guard number != nil || !fields.keys.isDisjoint(with: PackFormat.Keys.entryMarkers) else {
            return .notAnEntry
        }

        var issues: [DubPackIssue] = []

        // The format allows several timestamps per entry, but the app performs one line at a
        // time, so the first drives playback and the rest are reported as lost.
        let timestamps = fields.list(PackFormat.Keys.timestamps)
        guard let firstTimestamp = timestamps.first else { return .dropped(.missingTimestamp) }
        guard let startTime = TimestampParser.seconds(from: firstTimestamp) else { return .dropped(.invalidTimestamp) }
        if timestamps.count > 1 {
            issues.append(.extraTimestampsIgnored(file: entry.name, count: timestamps.count - 1))
        }

        guard let audio = referenceAudio(for: entry, fields: fields) else {
            return .dropped(hasAudioFile(for: entry, fields: fields) ? .unplayableAudio : .missingAudio)
        }

        let still = fields.string(PackFormat.Keys.image).flatMap(directory.file(named:))
            ?? directory.file(stem: entry.stem, extensions: PackFormat.Files.imageExtensions)
        if still == nil {
            issues.append(.missingStill(file: entry.name, substitute: fallbackStill))
        }

        let line = ParsedLine(
            index: number ?? position,
            slug: entry.stem,
            character: fields.string(PackFormat.Keys.characters) ?? Self.characterName(fromSlug: entry.stem),
            caption: fields.string(PackFormat.Keys.caption) ?? "",
            imageFile: still?.name ?? fallbackStill,
            referenceAudioFile: audio.file.name,
            startTime: startTime,
            duration: audio.duration
        )
        return .line(line, issues: issues)
    }

    /// "018_Mr_Dursley" -> "Mr Dursley", "03-Peter Parker" -> "Peter Parker".
    static func characterName(fromSlug slug: String) -> String {
        let name = slug
            .drop { $0.isNumber || $0 == "_" || $0 == "-" || $0 == " " || $0 == "." }
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? slug : name
    }

    // MARK: - Audio

    /// The named audio file, then the entry's own `stem.<extension>` in preference order.
    private func audioCandidates(for entry: PackFile, fields: PackFields) -> [PackFile] {
        let named = fields.string(PackFormat.Keys.audio).flatMap(directory.file(named:))
        let beside = directory.files(stem: entry.stem, extensions: PackFormat.Files.audioExtensions)

        var seen = Set<String>()
        return ([named].compactMap { $0 } + beside).filter { seen.insert(PackDirectory.key($0.name)).inserted }
    }

    private func hasAudioFile(for entry: PackFile, fields: PackFields) -> Bool {
        !audioCandidates(for: entry, fields: fields).isEmpty
    }

    /// The first candidate that actually decodes. A `.wav` and an `.mp3` of the same line is
    /// not unusual, and one of them being broken should not cost the line.
    private func referenceAudio(for entry: PackFile, fields: PackFields) -> (file: PackFile, duration: TimeInterval)? {
        for candidate in audioCandidates(for: entry, fields: fields) {
            if let duration = probe.audioDuration(of: candidate.url) {
                return (candidate, duration)
            }
        }
        return nil
    }
}
