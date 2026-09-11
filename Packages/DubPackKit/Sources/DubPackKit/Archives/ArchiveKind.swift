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
        if let head = leadingBytes(of: url, count: 6) {
            if head.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) { return .sevenZip }
            if head.count >= 4, head[0] == 0x50, head[1] == 0x4B, [0x03, 0x05, 0x07].contains(head[2]) {
                return .zip
            }
            return nil
        }
        return ArchiveKind(fileExtension: url.pathExtension)
    }

    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "zip": self = .zip
        case "7z": self = .sevenZip
        default: return nil
        }
    }

    private static func leadingBytes(of url: URL, count: Int) -> [UInt8]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: count) else { return nil }
        return [UInt8](data)
    }
}
