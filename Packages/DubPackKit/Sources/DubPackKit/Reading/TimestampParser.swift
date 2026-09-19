//
//  TimestampParser.swift
//  DubPackKit
//

import Foundation

/// Reads a line's start time as the format writes it, `6.716`, and as people type it by hand:
/// `6,716`, `6.716s`, `1:06.716`, `0:01:06.716`.
enum TimestampParser {

    /// Seconds from the start of the scene, or nil for anything that is not a time.
    static func seconds(from text: String) -> TimeInterval? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasSuffix("s") { value.removeLast() }
        value = value.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }

        let fields = value.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count <= 3 else { return nil }

        var total: TimeInterval = 0
        for field in fields {
            guard let number = TimeInterval(field.replacingOccurrences(of: ",", with: ".")),
                  number.isFinite, number >= 0 else { return nil }
            total = total * 60 + number
        }
        return total
    }
}
