//
//  String+NilIfEmpty.swift
//  DubloonFoundation
//

import Foundation

extension String {
    /// The string without surrounding whitespace, or nil when nothing is left.
    public var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
