//
//  DeepLinkTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Deep Link") @MainActor
struct DeepLinkTests {

    private func link(_ string: String) -> DeepLink? {
        DeepLink(url: URL(string: string)!)
    }

    @Test(arguments: [
        ("dubloon://game/movie-dub", GameMode.dub),
        ("dubloon://game/reverse-singing", .reverse),
        ("dubloon://game/sound-imitation", .imitate),
        ("dubloon://game/home-video-dub", .homeVideo),
    ])
    func gamePages(url: String, mode: GameMode) {
        #expect(link(url) == .game(mode))
    }

    /// Spooky Voice Week opens Sound Imitation.
    @Test func spookyEvent() {
        #expect(link("dubloon://event/spooky") == .game(.imitate))
    }

    @Test func toleratesCaseTrailingSlashAndQuery() {
        #expect(link("DUBLOON://Game/Movie-Dub/") == .game(.dub))
        #expect(link("dubloon://game/movie-dub?ct=cpp") == .game(.dub))
        #expect(link("dubloon:///game/movie-dub") == .game(.dub))
    }

    /// Unknown paths are still ours, so they open the app, but go nowhere in it.
    @Test(arguments: [
        "dubloon://",
        "dubloon://game",
        "dubloon://game/karaoke",
        "dubloon://event/christmas",
        "dubloon://store/movie-dub",
    ])
    func unknownPathsParseToNothing(url: String) {
        #expect(link(url) == nil)
        #expect(DeepLink.isDeepLinkURL(URL(string: url)!))
    }

    /// A dub pack opened from Files must keep reaching the importer.
    @Test func fileURLsAreNotDeepLinks() {
        let pack = URL(fileURLWithPath: "/tmp/game/movie-dub.zip")
        #expect(!DeepLink.isDeepLinkURL(pack))
        #expect(DeepLink(url: pack) == nil)
        #expect(link("https://dubloon.app/game/movie-dub") == nil)
    }
}
