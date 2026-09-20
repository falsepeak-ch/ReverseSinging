//
//  TimestampParser.swift
//  DubPackKit
//

import Foundation

/// Reads a line's start time as the format writes it, `6.716`, and as people and their tools
/// write it by hand: `6,716`, `6.716s`, `1:06.716`, `0:01:06.716`, `00:01:06,716` (SRT),
/// `01:06:12:14` (with frames), `1m6.7s`, `[6.716]`, `t=6.716` and `6.716 - 9.2` (a range).
///
/// Anything that looks like a time is read, because a line dropped for its timestamp is a line
/// the user cannot perform, and the format never said how a time had to be written.
///
/// The last resort is what the game these packs were made for does: it reads the number a value
/// starts with and ignores the rest. One real pack writes `070.010.110` for half its lines and
/// plays correctly there, at 70.010 seconds, so it has to play here too.
enum TimestampParser {

    /// Seconds from the start of the scene, or nil for anything that is not a time.
    static func seconds(from text: String) -> TimeInterval? {
        guard var value = normalised(text) else { return nil }
        if let start = rangeStart(of: value) { value = start }
        if let units = unitSeconds(value) { return units }
        if let clock = clockSeconds(value) { return clock }
        return leadingNumber(of: value)
    }

    /// The number a value starts with, `70.010` for `070.010.110` and `6.7` for `6.7-`, the way
    /// the original game reads a float. Never for a clock time: `1:x` is a typing mistake with
    /// no safe reading, where a second decimal point is only ever trailing noise.
    private static func leadingNumber(of value: String) -> TimeInterval? {
        guard !value.contains(":"), value.first?.isNumber == true else { return nil }

        var number = ""
        var hasSeparator = false
        for character in value {
            if character.isNumber {
                number.append(character)
            } else if (character == "." || character == ","), !hasSeparator {
                hasSeparator = true
                number.append(".")
            } else {
                break
            }
        }
        if number.hasSuffix(".") { number.removeLast() }
        guard let seconds = TimeInterval(number), seconds.isFinite else { return nil }
        return seconds
    }

    // MARK: - Cleaning

    /// Lower-cased, trimmed, unwrapped from brackets and quotes, without a `t=` style prefix,
    /// with every dash and arrow made ASCII. Nil when nothing is left.
    private static func normalised(_ text: String) -> String? {
        var value = text
            .replacingOccurrences(of: "\u{2013}", with: "-")   // en dash
            .replacingOccurrences(of: "\u{2014}", with: "-")   // em dash
            .replacingOccurrences(of: "\u{2192}", with: "->")  // arrow
            .replacingOccurrences(of: "\u{00A0}", with: " ")   // no-break space
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // One layer of wrapping, however it was typed.
        for (open, close) in [("[", "]"), ("(", ")"), ("{", "}"), ("\"", "\""), ("'", "'"), ("<", ">")] {
            if value.count >= 2, value.hasPrefix(open), value.hasSuffix(close) {
                value = String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            }
        }

        // `t=6.7`, `start: 6.7`, `time 6.7`, `@6.7`: the value is what follows.
        for prefix in ["timestamp", "start_time", "start", "time", "at", "t", "@"] {
            if value.hasPrefix(prefix) {
                let rest = value.dropFirst(prefix.count)
                let afterSeparator = rest.drop { $0 == "=" || $0 == ":" || $0 == " " }
                // Only a real prefix: `t` in `t=6.7`, not the `t` that `three` starts with.
                if afterSeparator.count < rest.count || prefix == "@", afterSeparator.first?.isNumber == true {
                    value = String(afterSeparator)
                    break
                }
            }
        }

        value = value.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// The first half of `6.7-9.2`, `6.7 -> 9.2`, `6.7..9.2`, `1:06 to 1:09`; nil for anything
    /// that is not two times either side of a separator.
    private static func rangeStart(of value: String) -> String? {
        for separator in [" to ", "->", "..", " - ", "-"] {
            guard let range = value.range(of: separator), range.lowerBound != value.startIndex else { continue }
            let start = String(value[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let end = String(value[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !start.isEmpty, !end.isEmpty,
                  unitSeconds(start) != nil || clockSeconds(start) != nil,
                  unitSeconds(end) != nil || clockSeconds(end) != nil else { continue }
            return start
        }
        return nil
    }

    // MARK: - Forms

    /// `1h2m3.5s`, `1m 23s`, `83s`, `500ms`: number-unit pairs that account for the whole text.
    private static func unitSeconds(_ value: String) -> TimeInterval? {
        var rest = Substring(value)
        var total: TimeInterval = 0
        var pairs = 0

        while !rest.isEmpty {
            rest = rest.drop { $0 == " " }
            let digits = rest.prefix { $0.isNumber || $0 == "." || $0 == "," }
            guard !digits.isEmpty, let number = decimal(String(digits)) else { return nil }
            rest = rest.dropFirst(digits.count).drop { $0 == " " }
            let unit = rest.prefix { $0.isLetter }
            rest = rest.dropFirst(unit.count)

            switch unit {
            case "h", "hr", "hrs", "hour", "hours": total += number * 3600
            case "m", "min", "mins", "minute", "minutes": total += number * 60
            case "s", "sec", "secs", "second", "seconds": total += number
            case "ms", "msec", "millis", "milliseconds": total += number / 1000
            // A bare number is not this form. `clockSeconds` reads it.
            default: return nil
            }
            pairs += 1
        }

        return pairs > 0 && total.isFinite ? total : nil
    }

    /// `6.716`, `1:06.716`, `0:01:06.716`, and `01:06:12:14` with the frame count ignored, since
    /// a pack never says its frame rate and a line a fraction of a second out still plays.
    private static func clockSeconds(_ value: String) -> TimeInterval? {
        var text = value
        for suffix in ["seconds", "second", "secs", "sec", "s"] where text.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        guard !text.isEmpty else { return nil }

        // `;` separates frames in drop-frame timecode.
        var fields = text.replacingOccurrences(of: ";", with: ":")
            .split(separator: ":", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard (1...4).contains(fields.count), !fields.contains("") else { return nil }

        if fields.count == 4 {
            fields.removeLast()
            // Frames cannot carry the decimal point; a fraction there is not a time.
            guard fields.allSatisfy({ !$0.contains(".") && !$0.contains(",") }) else { return nil }
        }

        var total: TimeInterval = 0
        for (offset, field) in fields.enumerated() {
            guard let number = decimal(field), number >= 0 else { return nil }
            // Only the last field may carry a fraction: `1.5:30` is not a time.
            if offset < fields.count - 1, number != number.rounded() { return nil }
            total = total * 60 + number
        }
        return total.isFinite ? total : nil
    }

    /// A non-negative number written with `.` or `,` as its decimal separator, and with the
    /// other, when both appear, as a thousands separator: `1,5`, `1.234,5` and `1,234.5`.
    private static func decimal(_ text: String) -> TimeInterval? {
        var value = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, !value.hasPrefix("-"), !value.hasPrefix("+") else { return nil }

        let lastDot = value.lastIndex(of: ".")
        let lastComma = value.lastIndex(of: ",")
        switch (lastDot, lastComma) {
        case (let dot?, let comma?):
            // Whichever comes last is the decimal point; the other only groups digits.
            let grouping: Character = dot > comma ? "," : "."
            value = value.replacingOccurrences(of: String(grouping), with: "")
            value = value.replacingOccurrences(of: ",", with: ".")
        case (nil, .some):
            value = value.replacingOccurrences(of: ",", with: ".")
        default:
            break
        }

        guard value.allSatisfy({ $0.isNumber || $0 == "." }), value.filter({ $0 == "." }).count <= 1,
              let number = TimeInterval(value), number.isFinite else { return nil }
        return number
    }
}
