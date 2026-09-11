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
    ])
    func readsTheWaysPeopleWriteATime(text: String, seconds: Double) {
        #expect(TimestampParser.seconds(from: text) == seconds)
    }

    @Test(arguments: ["", "s", "abc", "-1", "1:2:3:4", "1:x", "1::2", "inf"])
    func refusesWhatIsNotATime(text: String) {
        #expect(TimestampParser.seconds(from: text) == nil)
    }
}
