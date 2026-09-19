//
//  ArchiveExtraction.swift
//  DubPackKit
//

import Foundation

/// Why an archive extractor stopped.
enum ExtractionError: Error, Sendable, Equatable {
    case failed(ArchiveFailure)
    case cancelled
}

/// What an extraction did, beyond succeeding.
struct ExtractionSummary: Sendable, Equatable {
    /// Entries refused for pointing outside the destination.
    var skippedEntries: Int
    /// Set when the archive could only be read by recovering its entries one by one.
    var recovery: ArchiveRecovery? = nil
}

/// What was salvaged from a zip whose index could not be used.
struct ArchiveRecovery: Sendable, Equatable {
    /// The file ends before its index: the archive was cut off.
    var indexMissing: Bool
    /// The file the end of the archive cut through, relative to the unpacking folder.
    var truncatedEntry: String?
    /// Whether that partial file was kept. Only audio is: a partial recording still plays.
    var partialKept: Bool
    /// Entries that failed their checksum or would not decompress, and were left out.
    var damagedEntries: Int

    /// False when every entry came out whole and the index was refused for another reason, such
    /// as an unsafe entry name, which is reported on its own.
    var isDegraded: Bool {
        indexMissing || truncatedEntry != nil || damagedEntries > 0
    }
}

/// Carries a Swift progress handler across a C extractor's callback, and throttles it: the C side
/// reports every write, which is thousands of calls for one pack. `report` returning false stops
/// the extraction, which is how task cancellation reaches the C code.
final class ExtractionProgressRelay {
    private let handler: (@Sendable (Double) -> Void)?
    private var lastReported = -1.0

    init(handler: (@Sendable (Double) -> Void)?) {
        self.handler = handler
    }

    func report(done: UInt64, total: UInt64) -> Bool {
        if Task.isCancelled { return false }
        guard let handler else { return true }
        let fraction = total > 0 ? min(1, Double(done) / Double(total)) : 1
        if fraction - lastReported >= 0.01 || fraction == 1 {
            lastReported = fraction
            handler(fraction)
        }
        return true
    }
}

extension String {
    /// The NUL-terminated string a C function wrote into `buffer`.
    init(cBuffer buffer: [CChar]) {
        self = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
