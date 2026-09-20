//
//  ArchiveKind.swift
//  DubPackKit
//

import Foundation

/// The archive formats a pack can arrive in.
enum ArchiveKind: String, Sendable {
    case zip
    case sevenZip = "7z"

    /// What the file is, by its first bytes before its name.
    ///
    /// Chat apps and mail clients rename attachments: a `.7z` renamed to `.zip` to get past a
    /// filter is still a `.7z`, and handing it to the zip reader fails with a message about
    /// nothing. The extension decides only when the bytes cannot be read.
    static func detect(at url: URL) -> ArchiveKind? {
        guard let head = leadingBytes(of: url, count: 8) else {
            return ArchiveKind(fileExtension: url.pathExtension)
        }
        if head.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) { return .sevenZip }
        if head.count >= 4, head[0] == 0x50, head[1] == 0x4B, [0x03, 0x05, 0x07].contains(head[2]) {
            return .zip
        }
        return nil
    }

    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "zip": self = .zip
        case "7z": self = .sevenZip
        default: return nil
        }
    }

    /// A short English name for what a file that is not an archive actually holds, by its
    /// first bytes: `html`, `mp4`, `icloud_placeholder`, `empty`. For the crash report and the
    /// message, since "not a zip" explains nothing about a file called `scene.zip`.
    static func looksLike(_ url: URL) -> String {
        guard let head = leadingBytes(of: url, count: 16) else { return "unreadable" }
        guard !head.isEmpty else { return "empty" }

        let ascii = String(decoding: head.prefix(16), as: UTF8.self).lowercased()
        if ascii.hasPrefix("bplist") { return "icloud_placeholder" }
        if ascii.hasPrefix("<!doctype") || ascii.hasPrefix("<html") || ascii.hasPrefix("<?xml") || ascii.hasPrefix("<") { return "html" }
        if ascii.hasPrefix("{") || ascii.hasPrefix("[") { return "json" }
        if ascii.hasPrefix("rar!") { return "rar" }
        if ascii.hasPrefix("id3") { return "mp3" }
        if ascii.hasPrefix("oggs") { return "ogg" }
        if ascii.hasPrefix("riff") { return "riff" }
        if ascii.hasPrefix("fLaC".lowercased()) { return "flac" }
        if ascii.hasPrefix("%pdf") { return "pdf" }
        if head.count >= 8, String(decoding: head[4..<8], as: UTF8.self) == "ftyp" { return "mp4" }
        if head.starts(with: [0x1F, 0x8B]) { return "gzip" }
        if head.starts(with: [0x42, 0x5A, 0x68]) { return "bzip2" }
        if head.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) { return "xz" }
        if head.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if head.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpeg" }
        if head.starts(with: [0xFF, 0xFB]) || head.starts(with: [0xFF, 0xF3]) || head.starts(with: [0xFF, 0xF2]) { return "mp3" }
        if head.starts(with: [0x50, 0x4B]) { return "damaged_zip" }
        if head.allSatisfy({ $0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D || (0x20...0x7E).contains($0) }) { return "text" }
        return head.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    /// The file's first bytes: empty for an empty file, nil for one that cannot be opened.
    private static func leadingBytes(of url: URL, count: Int) -> [UInt8]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: count) else { return [] }
        return [UInt8](data)
    }
}
