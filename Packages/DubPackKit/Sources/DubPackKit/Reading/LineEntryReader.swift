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
///
/// An entry is recognised three ways: by the number its name starts with, by carrying any of
/// the format's keys, or by having a recording of the same name beside it. The last is how a
/// pack written by hand, `cady.txt` + `cady.mp3`, still comes in.
struct LineEntryReader: Sendable {

    enum Outcome: Sendable, Equatable {
        case line(ParsedLine, issues: [DubPackIssue])
        /// `detail` is the value that could not be read, when there is one.
        case dropped(DroppedLineReason, detail: String? = nil)
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
        let hasRecording = directory.hasRecording(beside: entry)

        guard let text = PackTextDecoder.read(at: entry.url) else {
            // A numbered file that will not read is a lost line; an unreadable note is not.
            return number == nil && !hasRecording ? .notAnEntry : .dropped(.unreadableText)
        }

        let fields = PackFields(parsing: text)
        let isMarked = !fields.keys.isDisjoint(with: PackFormat.Keys.entryMarkers)
        guard number != nil || isMarked || hasRecording else {
            return .notAnEntry
        }

        var issues: [DubPackIssue] = []

        // The format allows several timestamps per entry, but the app performs one line at a
        // time, so the first drives playback and the rest are reported as lost. An entry with
        // none may still carry its time in its name, `01_Cady_12.5.txt`.
        var timestamps = fields.list(PackFormat.Keys.timestamps)
        if timestamps.isEmpty, let named = Self.timestamp(inStem: entry.stem) {
            timestamps = [named]
        }
        guard let firstTimestamp = timestamps.first else { return .dropped(.missingTimestamp) }
        guard let startTime = TimestampParser.seconds(from: firstTimestamp) else {
            return .dropped(.invalidTimestamp, detail: firstTimestamp)
        }
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

        // A file with no `key = value` lines at all is the caption itself, typed plain.
        let caption = fields.string(PackFormat.Keys.caption)
            ?? (fields.keys.isEmpty ? Self.plainCaption(text) : "")

        let line = ParsedLine(
            index: number ?? position,
            slug: entry.stem,
            character: fields.string(PackFormat.Keys.characters) ?? Self.characterName(fromSlug: entry.stem),
            caption: caption,
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

    /// A time written into the entry's name, after its number: `01_Cady_12.5`, `Cady@1:23`,
    /// `07 - Regina (1m23s)`. Only something with a fraction, a colon or a unit counts, so the
    /// `2` in `Peter Parker 2` is never mistaken for two seconds.
    static func timestamp(inStem stem: String) -> String? {
        let separators = CharacterSet(charactersIn: "_-@ ()[]")
        let tokens = stem.components(separatedBy: separators).filter { !$0.isEmpty }
        guard tokens.count > 1 else { return nil }

        for token in tokens.dropFirst().reversed() {
            let looksTimed = token.contains(".") || token.contains(",") || token.contains(":")
                || token.last.map { $0 == "s" || $0 == "m" || $0 == "h" } == true
            guard looksTimed, token.first?.isNumber == true, TimestampParser.seconds(from: token) != nil else { continue }
            return token
        }
        return nil
    }

    /// The text of an entry that has no fields, as its caption: every line that is not a
    /// section header, joined.
    static func plainCaption(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") && !$0.hasPrefix("#") && !$0.hasPrefix(";") }
            .joined(separator: " ")
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
