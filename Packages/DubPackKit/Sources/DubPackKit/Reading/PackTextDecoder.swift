//
//  PackTextDecoder.swift
//  DubPackKit
//

import Foundation

/// Reads pack text files in whatever encoding their author's editor saved them in.
///
/// In order: UTF-8 with or without a byte-order mark, UTF-16 with a mark, UTF-16 without one,
/// then Windows-1252 and Latin-1 for the Windows editors that still default to them. The last
/// two decode any bytes at all, so their result must also look like text: a `.txt` that is
/// really a renamed image is unreadable, not a page of noise.
enum PackTextDecoder {

    static func read(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }
        // Before UTF-8, because plain ASCII written as UTF-16 is also valid UTF-8, NULs and all.
        if looksLikeUTF16(data), let text = String(data: data, encoding: .utf16LittleEndian) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        guard let text = String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1),
              looksLikeText(text) else {
            return nil
        }
        return text
    }

    /// UTF-16 without a byte-order mark shows itself as text full of NUL bytes.
    private static func looksLikeUTF16(_ data: Data) -> Bool {
        data.count >= 4 && data.count.isMultiple(of: 2) && data.filter { $0 == 0 }.count > data.count / 4
    }

    /// False when more than one character in twenty is a control character other than tab,
    /// newline or carriage return.
    private static func looksLikeText(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        guard !scalars.isEmpty else { return true }
        let controls = scalars.filter { $0.value < 0x20 && !["\t", "\n", "\r"].contains($0) }.count
        return controls * 20 <= scalars.count
    }
}
