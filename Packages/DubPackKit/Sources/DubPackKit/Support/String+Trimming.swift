//
//  String+Trimming.swift
//  DubPackKit
//

import Foundation

extension String {
    /// The string without surrounding whitespace, or nil when nothing is left.
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
