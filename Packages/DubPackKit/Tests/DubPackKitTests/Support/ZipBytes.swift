//
//  ZipBytes.swift
//  DubPackKitTests
//

import Foundation

/// Byte-level surgery on the streamed zip fixtures, to make the damaged archives recovery exists for.
enum ZipBytes {

    struct LocalEntry {
        let offset: Int
        let name: String
        let dataStart: Int
    }

    private static let localHeader: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
    private static let centralHeader: [UInt8] = [0x50, 0x4B, 0x01, 0x02]

    /// Local headers in order, recognised by their names so that four bytes inside a recording
    /// cannot pass for one.
    static func localEntries(in data: Data) -> [LocalEntry] {
        let bytes = [UInt8](data)
        let end = indexStart(in: data) ?? bytes.count
        var entries: [LocalEntry] = []

        for offset in occurrences(of: localHeader, in: bytes) where offset < end && offset + 30 <= bytes.count {
            let nameLength = Int(bytes[offset + 26]) | Int(bytes[offset + 27]) << 8
            let extraLength = Int(bytes[offset + 28]) | Int(bytes[offset + 29]) << 8
            guard offset + 30 + nameLength <= bytes.count else { continue }
            let name = String(decoding: bytes[(offset + 30)..<(offset + 30 + nameLength)], as: UTF8.self)
            guard name.hasPrefix("Streamed Pack/") || name.hasPrefix("../") else { continue }
            entries.append(LocalEntry(offset: offset, name: name, dataStart: offset + 30 + nameLength + extraLength))
        }
        return entries
    }

    /// Where the index starts: the first central header naming a pack file.
    static func indexStart(in data: Data) -> Int? {
        let bytes = [UInt8](data)
        return occurrences(of: centralHeader, in: bytes).first { offset in
            guard offset + 46 + 14 <= bytes.count else { return false }
            return String(decoding: bytes[(offset + 46)..<(offset + 60)], as: UTF8.self) == "Streamed Pack/"
        }
    }

    /// The archive without its index, as a download cut off right after the last entry leaves it.
    static func withoutIndex(_ data: Data) -> Data {
        data.prefix(indexStart(in: data)!)
    }

    /// The archive cut off halfway through the data of the entry whose name ends with `suffix`.
    static func cut(_ data: Data, insideEntryEndingWith suffix: String) -> Data {
        let entries = localEntries(in: data)
        let position = entries.firstIndex { $0.name.hasSuffix(suffix) }!
        let entry = entries[position]
        let next = position + 1 < entries.count ? entries[position + 1].offset : indexStart(in: data)!
        return data.prefix(entry.dataStart + (next - entry.dataStart) / 2)
    }

    /// The archive with one byte of an entry's data flipped.
    static func corrupting(_ data: Data, entryEndingWith suffix: String, at offset: Int = 200) -> Data {
        var copy = data
        let entry = localEntries(in: data).first { $0.name.hasSuffix(suffix) }!
        copy[entry.dataStart + offset] ^= 0xFF
        return copy
    }

    /// The archive with a 16-bit field of an entry's local header replaced: flags live at 6, the
    /// compression method at 8.
    static func setting(_ data: Data, field offset: Int, to value: UInt16, entryEndingWith suffix: String) -> Data {
        var copy = data
        let entry = localEntries(in: data).first { $0.name.hasSuffix(suffix) }!
        copy[entry.offset + offset] = UInt8(value & 0xFF)
        copy[entry.offset + offset + 1] = UInt8(value >> 8)
        return copy
    }

    private static func occurrences(of signature: [UInt8], in bytes: [UInt8]) -> [Int] {
        guard bytes.count >= signature.count else { return [] }
        return (0...(bytes.count - signature.count)).filter { offset in
            bytes[offset] == signature[0] && Array(bytes[offset..<(offset + signature.count)]) == signature
        }
    }
}
