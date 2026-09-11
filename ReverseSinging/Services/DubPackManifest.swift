//
//  DubPackManifest.swift
//  ReverseSinging
//
//  The cached description of an installed dub pack
//

import Foundation

/// `manifest.json` in each installed pack's folder: the `DubPack` as last read, so a launch
/// does not re-read sixty text files and re-measure every reference recording per pack.
nonisolated enum DubPackManifest {

    static let filename = "manifest.json"

    static func read(at directory: URL) -> DubPack? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(filename)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DubPack.self, from: data)
    }

    static func write(_ pack: DubPack, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pack)
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
    }
}
