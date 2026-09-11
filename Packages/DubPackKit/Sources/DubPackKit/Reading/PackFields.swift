//
//  PackFields.swift
//  DubPackKit
//

import Foundation

/// The `key = value` fields of one pack text file: `_pack_info.ini`, or a line entry.
///
/// The syntax is INI-like and read tolerantly. `[section]` headers, blank lines and `#` or `;`
/// comments are skipped. Keys ignore case. A value is a quoted or bare scalar, or a bracketed
/// list whose quoted elements may contain commas. Lines are split on their first `=` only,
/// because captions contain `=` as often as anything else.
struct PackFields: Sendable, Equatable {

    enum Value: Sendable, Equatable {
        case scalar(String)
        case list([String])

        /// The scalar, or a list's first element.
        var first: String? {
            switch self {
            case .scalar(let value): value
            case .list(let values): values.first
            }
        }

        /// A list's elements, or the scalar on its own.
        var all: [String] {
            switch self {
            case .scalar(let value): [value]
            case .list(let values): values
            }
        }
    }

    private let values: [String: Value]

    init() {
        values = [:]
    }

    init(parsing text: String) {
        var values: [String: Value] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            guard !line.isEmpty,
                  !line.hasPrefix("["),
                  !line.hasPrefix("#"),
                  !line.hasPrefix(";"),
                  let separator = line.firstIndex(of: "=") else { continue }

            let key = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let rawValue = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)

            guard !key.isEmpty else { continue }

            values[key] = rawValue.hasPrefix("[")
                ? .list(Self.splitList(rawValue))
                : .scalar(Self.unquote(rawValue))
        }

        self.values = values
    }

    subscript(key: String) -> Value? {
        values[key.lowercased()]
    }

    var keys: Set<String> {
        Set(values.keys)
    }

    /// The first non-blank value under any of `keys`, trimmed.
    func string(_ keys: [String]) -> String? {
        for key in keys {
            if let value = self[key]?.first?.trimmedOrNil { return value }
        }
        return nil
    }

    /// The non-blank elements under the first of `keys` that has any.
    func list(_ keys: [String]) -> [String] {
        for key in keys {
            let elements = (self[key]?.all ?? []).compactMap(\.trimmedOrNil)
            if !elements.isEmpty { return elements }
        }
        return []
    }

    // MARK: - Syntax

    /// Strips one pair of surrounding double or single quotes, and unescapes `\"` and `\\`.
    static func unquote(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)

        if value.count >= 2,
           let quote = value.first, quote == "\"" || quote == "'",
           value.last == quote {
            value = String(value.dropFirst().dropLast())
        }

        return value
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    /// Splits `["a", "b, c"]` or `[0.0, 1.5]` into its elements, honouring quotes.
    static func splitList(_ raw: String) -> [String] {
        var body = Substring(raw.trimmingCharacters(in: .whitespaces))
        guard body.hasPrefix("[") else { return [unquote(String(body))] }

        body = body.dropFirst()
        if body.hasSuffix("]") { body = body.dropLast() }

        var elements: [String] = []
        var current = ""
        var insideQuotes = false
        var escaped = false

        for character in body {
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                insideQuotes.toggle()
            } else if character == ",", !insideQuotes {
                elements.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        elements.append(current)

        return elements.map(unquote).filter { !$0.isEmpty }
    }
}
