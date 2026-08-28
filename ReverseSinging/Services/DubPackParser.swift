//
//  DubPackParser.swift
//  ReverseSinging
//
//  Reads the community dub-pack format from a directory on disk
//

import Foundation
import AVFoundation

// MARK: - Errors

nonisolated enum DubPackError: LocalizedError {
    case missingPackInfo
    case noLines
    case missingAsset(String)
    case notAFolder
    case unreadableArchive(Error)

    var errorDescription: String? {
        switch self {
        case .missingPackInfo:
            return Strings.Dub.Error.missingPackInfo
        case .noLines:
            return Strings.Dub.Error.noLines
        case .missingAsset(let name):
            return String(format: Strings.Dub.Error.missingAsset, name)
        case .notAFolder:
            return Strings.Dub.Error.notAFolder
        case .unreadableArchive(let error):
            return String(format: Strings.Dub.Error.unreadableArchive, error.localizedDescription)
        }
    }
}

// MARK: - Parser

/// Parses the `[data]` / `key="value"` format shared by `_pack_info.ini` and the per-line
/// `.txt` files. Deliberately tolerant: unknown keys are ignored, sections are skipped, and
/// a line the parser can't make sense of is dropped rather than failing the whole pack.
nonisolated enum DubPackParser {

    static let packInfoFilename = "_pack_info.ini"
    /// Packs ship the backing track as `_backing_track.mp3`, but the extension isn't
    /// guaranteed, so it's matched on the stem.
    static let backingTrackPrefix = "_backing_track"
    /// The scene video ships as `dub_video.<ext>`. Matched on the stem for the same reason
    /// as the backing track: the extension varies by how the pack was produced.
    static let videoPrefix = "dub_video"
    static let manifestFilename = "manifest.json"

    // MARK: - Key/Value Parsing

    /// A parsed value: either a scalar string or an array of strings.
    enum Value {
        case scalar(String)
        case array([String])

        var stringValue: String? {
            switch self {
            case .scalar(let value): return value
            case .array(let values): return values.first
            }
        }

        var arrayValue: [String] {
            switch self {
            case .scalar(let value): return [value]
            case .array(let values): return values
            }
        }
    }

    static func parseKeyValues(_ contents: String) -> [String: Value] {
        var result: [String: Value] = [:]

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Skip blanks, section headers and comments
            guard !line.isEmpty,
                  !line.hasPrefix("["),
                  !line.hasPrefix("#"),
                  !line.hasPrefix(";") else { continue }

            // Split on the FIRST '=' only: captions contain '=' as often as anything else
            guard let separator = line.firstIndex(of: "=") else { continue }

            let key = String(line[line.startIndex..<separator]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)

            guard !key.isEmpty else { continue }

            if rawValue.hasPrefix("[") {
                result[key] = .array(parseArray(rawValue))
            } else {
                result[key] = .scalar(unquote(rawValue))
            }
        }

        return result
    }

    /// Strips surrounding quotes and unescapes `\"` and `\\`.
    static func unquote(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)

        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }

        return value
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    /// Splits `["a", "b"]` / `[0.0, 1.5]` into elements, honouring quotes so that a comma
    /// inside a quoted element doesn't split it.
    static func parseArray(_ raw: String) -> [String] {
        var body = raw.trimmingCharacters(in: .whitespaces)
        guard body.hasPrefix("[") else { return [unquote(body)] }

        body = String(body.dropFirst())
        if body.hasSuffix("]") { body = String(body.dropLast()) }

        var elements: [String] = []
        var current = ""
        var insideQuotes = false
        var escaped = false

        for character in body {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                current.append(character)
                escaped = true
            } else if character == "\"" {
                insideQuotes.toggle()
                current.append(character)
            } else if character == ",", !insideQuotes {
                elements.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        elements.append(current)

        return elements
            .map { unquote($0) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Pack Parsing

    /// Reads a pack directory into a `DubPack`.
    /// - Parameters:
    ///   - directoryURL: the pack folder, containing `_pack_info.ini` and the line files.
    ///   - folderName: the name the pack is stored under inside `DubPacks/`.
    static func parsePack(at directoryURL: URL, folderName: String, id: UUID = UUID()) throws -> DubPack {
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DubPackError.notAFolder
        }

        let packInfoURL = directoryURL.appendingPathComponent(packInfoFilename)
        guard let packInfoContents = try? String(contentsOf: packInfoURL, encoding: .utf8) else {
            throw DubPackError.missingPackInfo
        }

        let packInfo = parseKeyValues(packInfoContents)
        let title = packInfo["title"]?.stringValue?.nilIfEmpty ?? folderName
        let authors = packInfo["authors"]?.arrayValue ?? []

        // Provenance. The build writes these for a pack cut from someone else's work;
        // a pack a user made themselves has none of them, and nil is the right answer.
        let source = packInfo["source"]?.stringValue?.nilIfEmpty
        let sourceURL = packInfo["source_url"]?.stringValue?.nilIfEmpty
        let rights = packInfo["rights"]?.stringValue?.nilIfEmpty

        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let lineFiles = contents
            .filter { $0.pathExtension.lowercased() == "txt" && !$0.lastPathComponent.hasPrefix("_") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        var lines: [DubLine] = []

        for (offset, lineFileURL) in lineFiles.enumerated() {
            guard let line = try parseLine(at: lineFileURL, in: directoryURL, fallbackIndex: offset + 1) else {
                continue
            }
            lines.append(line)
        }

        guard !lines.isEmpty else { throw DubPackError.noLines }

        lines.sort { $0.startTime < $1.startTime }

        // The icon named by the pack, falling back to the first line's still
        var iconFile = lines[0].imageFile
        if let named = packInfo["icon"]?.stringValue?.nilIfEmpty,
           fileManager.fileExists(atPath: directoryURL.appendingPathComponent(named).path) {
            iconFile = named
        }

        // Only a track AVFoundation can actually read counts. An Ogg Vorbis backing track
        // would parse fine here and then be silent everywhere else.
        let backingTrackFile = contents
            .first { $0.deletingPathExtension().lastPathComponent == backingTrackPrefix }
            .flatMap { AudioFileManager.shared.getAudioDuration(from: $0) != nil ? $0 : nil }

        let backingTrackDuration = backingTrackFile.flatMap { AudioFileManager.shared.getAudioDuration(from: $0) }
        let duration = backingTrackDuration ?? (lines.last?.endTime ?? 0)

        // Same guard as the backing track: a file named dub_video.ogv parses fine here and
        // then shows a black rectangle everywhere, so only accept one with a readable track.
        let videoFile = contents
            .first { $0.deletingPathExtension().lastPathComponent == videoPrefix }
            .flatMap { hasReadableVideoTrack(at: $0) ? $0 : nil }

        return DubPack(
            id: id,
            title: title,
            authors: authors,
            iconFile: iconFile,
            backingTrackFile: backingTrackFile?.lastPathComponent,
            videoFile: videoFile?.lastPathComponent,
            folderName: folderName,
            lines: lines,
            duration: duration,
            source: source,
            sourceURL: sourceURL,
            rights: rights
        )
    }

    /// Whether AVFoundation can see a video track in this file. Ogg Theora returns false,
    /// which is the whole point. The parser must not record an unplayable file as the video.
    static func hasReadableVideoTrack(at url: URL) -> Bool {
        let asset = AVURLAsset(url: url)
        return !asset.tracks(withMediaType: .video).isEmpty
    }

    /// Parses one `NNN_Character.txt` plus its sibling assets. Returns nil when the entry is
    /// unusable (no timestamp), throws when a referenced asset is missing.
    private static func parseLine(at url: URL, in directoryURL: URL, fallbackIndex: Int) throws -> DubLine? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let fields = parseKeyValues(contents)
        let slug = url.deletingPathExtension().lastPathComponent

        // "001_Dobby" -> 1
        let leadingDigits = slug.prefix { $0.isNumber }
        let index = Int(leadingDigits) ?? fallbackIndex

        // The format allows several timestamps/characters per entry; this app performs one
        // line at a time, so the first of each is what drives playback.
        guard let timestampString = fields["dub_timestamps"]?.arrayValue.first,
              let startTime = TimeInterval(timestampString) else {
            return nil
        }

        let character = fields["dub_characters"]?.arrayValue.first?.nilIfEmpty
            ?? slug.drop { $0.isNumber || $0 == "_" }.replacingOccurrences(of: "_", with: " ")

        let caption = fields["caption"]?.stringValue ?? ""

        let imageFile = fields["image"]?.stringValue?.nilIfEmpty ?? "\(slug).jpg"
        guard FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent(imageFile).path) else {
            throw DubPackError.missingAsset(imageFile)
        }

        let referenceAudioFile = "\(slug).wav"
        let referenceAudioURL = directoryURL.appendingPathComponent(referenceAudioFile)
        guard FileManager.default.fileExists(atPath: referenceAudioURL.path) else {
            throw DubPackError.missingAsset(referenceAudioFile)
        }

        let duration = AudioFileManager.shared.getAudioDuration(from: referenceAudioURL) ?? 0

        return DubLine(
            index: index,
            slug: slug,
            character: String(character),
            caption: caption,
            imageFile: imageFile,
            referenceAudioFile: referenceAudioFile,
            startTime: startTime,
            duration: duration,
            speech: speechWindow(at: referenceAudioURL, duration: duration)
        )
    }

    /// Measures where the dialogue sits inside a reference chunk.
    ///
    /// The one place this is done. Reading the whole wav is the expensive part of parsing a
    /// pack, which is exactly why the answer is written into the manifest and never computed
    /// again: playback, export, captions and scoring all read the stored window, so they
    /// cannot disagree about when a line happens.
    ///
    /// Falls back to the whole chunk for a reference that is silent or unreadable, no worse
    /// than the behaviour before windows existed.
    private static func speechWindow(at url: URL, duration: TimeInterval) -> DubSpeechWindow {
        guard duration > 0,
              let buffer = try? DubAudioLoader.loadVoiceBuffer(from: url, applyFades: false),
              let window = DubSpeechOnset.window(of: buffer) else {
            return DubSpeechWindow(start: 0, end: duration)
        }

        return DubSpeechWindow(
            start: min(max(0, window.start), duration),
            end: min(max(window.start, window.end), duration)
        )
    }
}

// MARK: - Helpers

nonisolated extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
