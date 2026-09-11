//
//  PackRootFinderTests.swift
//  DubPackKitTests
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("Pack root finder")
struct PackRootFinderTests {

    @Test func findsFilesAtTheTop() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let pack = try PackBuilder(in: temp.url, named: "unpacked")
        try pack.packInfo()

        #expect(PackRootFinder.root(in: pack.directory) == pack.directory)
    }

    @Test func findsThePackUnderWrappingFoldersAndSkipsFinderClutter() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let clutter = try PackBuilder(in: temp.url, named: "__MACOSX")
        try clutter.packInfo()
        let pack = try PackBuilder(in: temp.url.appendingPathComponent("release/v2"), named: "Scene")
        try pack.packInfo()

        #expect(PackRootFinder.root(in: temp.url)?.standardizedFileURL == pack.directory.standardizedFileURL)
    }

    @Test func prefersTheShallowestPackInfo() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let outer = try PackBuilder(in: temp.url, named: "a")
        try outer.packInfo()
        let inner = try PackBuilder(in: outer.directory, named: "bonus")
        try inner.packInfo()

        #expect(PackRootFinder.root(in: temp.url)?.standardizedFileURL == outer.directory.standardizedFileURL)
    }

    @Test func withoutPackInfoPicksTheFolderWithTheMostNumberedEntries() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let few = try PackBuilder(in: temp.url, named: "a")
        try few.write("x", to: "001_A.txt")
        let many = try PackBuilder(in: temp.url, named: "b")
        try many.write("x", to: "001_A.txt")
        try many.write("x", to: "002_A.txt")

        #expect(PackRootFinder.root(in: temp.url)?.lastPathComponent == "b")
    }

    @Test func givesUpBelowTheMaximumDepth() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let deep = try PackBuilder(in: temp.url.appendingPathComponent("1/2/3"), named: "4")
        try deep.packInfo()

        #expect(PackRootFinder.root(in: temp.url) == nil)
        #expect(PackRootFinder.root(in: temp.url, maxDepth: 4) != nil)
    }
}
