//
//  TimestampParserTests.swift
//  DubPackKitTests
//

import Testing
@testable import DubPackKit

@Suite("Timestamp parsing")
struct TimestampParserTests {

    @Test(arguments: [
        ("6.716", 6.716),
        ("6,716", 6.716),
        ("6.716s", 6.716),
        (" 12 ", 12.0),
        ("1:06.5", 66.5),
        ("0:01:06.5", 66.5),
        ("0", 0.0),
        // SRT and its cousins.
        ("00:01:06,500", 66.5),
        ("01:06:12:14", 3972.0),          // frames dropped
        ("01:06:12;14", 3972.0),          // drop-frame timecode
        // Units.
        ("1m6.5s", 66.5),
        ("1m 6s", 66.0),
        ("1h2m3s", 3723.0),
        ("500ms", 0.5),
        ("12 sec", 12.0),
        ("12 seconds", 12.0),
        // Wrapping and prefixes people leave in.
        ("[6.716]", 6.716),
        ("(6.716)", 6.716),
        ("\"6.716\"", 6.716),
        ("t=6.716", 6.716),
        ("start: 6.716", 6.716),
        ("@6.716", 6.716),
        // Ranges: the start is the line.
        ("6.716-9.2", 6.716),
        ("6.716 - 9.2", 6.716),
        ("1:06 -> 1:09", 66.0),
        ("1:06 → 1:09", 66.0),
        ("6.7..9.2", 6.7),
        ("6.7 to 9.2", 6.7),
        // Thousands separators, either way round.
        ("1.234,5", 1234.5),
        ("1,234.5", 1234.5),
        ("6.716\u{00A0}s", 6.716),
    ])
    func readsTheWaysPeopleWriteATime(text: String, seconds: Double) {
        #expect(TimestampParser.seconds(from: text) == seconds)
    }

    @Test(arguments: ["", "s", "abc", "-1", "1:2:3:4:5", "1:x", "1::2", "inf", "1.5:30", "three", "t=", "6.7-", "-6.7"])
    func refusesWhatIsNotATime(text: String) {
        #expect(TimestampParser.seconds(from: text) == nil)
    }
}
