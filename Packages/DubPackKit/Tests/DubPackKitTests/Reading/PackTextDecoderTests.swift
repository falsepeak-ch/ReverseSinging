//
//  PackTextDecoderTests.swift
//  DubPackKitTests
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("Pack text decoding")
struct PackTextDecoderTests {

    @Test func readsUTF8() {
        #expect(PackTextDecoder.decode(Data("caption=\"Où\"".utf8)) == "caption=\"Où\"")
    }

    @Test func dropsTheUTF8ByteOrderMark() {
        #expect(PackTextDecoder.decode(Data([0xEF, 0xBB, 0xBF]) + Data("title".utf8)) == "title")
    }

    @Test func readsUTF16WithAByteOrderMark() throws {
        let littleEndian = try #require("title=\"Wide\"".data(using: .utf16LittleEndian))
        let bigEndian = try #require("title=\"Wide\"".data(using: .utf16BigEndian))

        #expect(PackTextDecoder.decode(Data([0xFF, 0xFE]) + littleEndian) == "title=\"Wide\"")
        #expect(PackTextDecoder.decode(Data([0xFE, 0xFF]) + bigEndian) == "title=\"Wide\"")
    }

    @Test func readsUTF16WithoutAByteOrderMark() throws {
        let data = try #require("caption=\"Wide\"".data(using: .utf16LittleEndian))

        #expect(PackTextDecoder.decode(data) == "caption=\"Wide\"")
    }

    /// Notepad's old default. An accented caption in it is not valid UTF-8.
    @Test func readsWindows1252() throws {
        let data = try #require("caption=\"Où est le café ?\"".data(using: .windowsCP1252))

        #expect(PackTextDecoder.decode(data) == "caption=\"Où est le café ?\"")
    }

    /// Latin-1 decodes any bytes, so a renamed binary must still be refused.
    @Test func refusesBinaryData() {
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52])

        #expect(PackTextDecoder.decode(pngHeader) == nil)
    }
}
