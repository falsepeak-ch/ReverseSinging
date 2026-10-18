//
//  HelpContent.swift
//  ReverseSinging
//
//  What the Help screen knows: its sections and the questions in each
//

import Foundation

/// A chapter of Help. A screen that opens Help names the chapter it is about, so the answer
/// someone needs is the first thing they see.
nonisolated enum HelpTopic: String, CaseIterable, Identifiable, Sendable {
    case gettingStarted
    case reverse
    case dub
    case homeVideo
    case booth
    case packs
    case imitate
    case pro
    case privacy
    case troubleshooting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted: Strings.Help.Section.gettingStarted
        case .reverse: Strings.Main.Mode.reverseTitle
        case .dub: Strings.Main.Mode.dubTitle
        case .homeVideo: Strings.Main.Mode.homeVideoTitle
        case .booth: Strings.Help.Section.booth
        case .packs: Strings.Help.Section.packs
        case .imitate: Strings.Main.Mode.imitateTitle
        case .pro: Strings.Help.Section.pro
        case .privacy: Strings.Help.Section.privacy
        case .troubleshooting: Strings.Help.Section.troubleshooting
        }
    }

    var symbol: String {
        switch self {
        case .gettingStarted: "sparkles"
        case .reverse: "arrow.uturn.backward"
        case .dub: "film"
        case .homeVideo: "play.rectangle"
        case .booth: "video"
        case .packs: "shippingbox"
        case .imitate: "megaphone"
        case .pro: "star"
        case .privacy: "lock"
        case .troubleshooting: "wrench.and.screwdriver"
        }
    }

    /// How many questions the chapter has. The strings are `help.<topic>.<n>.q` and `.a`, from 1.
    private var articleCount: Int {
        switch self {
        case .gettingStarted: 3
        case .reverse: 5
        case .dub: 4
        case .homeVideo: 3
        case .booth: 3
        case .packs: 3
        case .imitate: 3
        case .pro: 3
        case .privacy: 2
        case .troubleshooting: 4
        }
    }

    var articles: [HelpArticle] {
        (1...articleCount).map { HelpArticle(topic: self, number: $0) }
    }
}

/// One question and its answer.
nonisolated struct HelpArticle: Identifiable, Hashable, Sendable {
    let topic: HelpTopic
    let number: Int

    var id: String { "\(topic.rawValue).\(number)" }

    var question: String { Self.text("help.\(id).q") }

    var answer: String { Self.text("help.\(id).a") }

    /// The Mac's wording where it has one (`….mac`: clicks, menus and System Settings rather
    /// than taps and the Settings app), and the shared text everywhere else.
    private static func text(_ key: String) -> String {
        #if os(macOS)
        let missing = "\u{0}"
        let mac = Bundle.main.localizedString(forKey: key + ".mac", value: missing, table: nil)
        if mac != missing { return mac }
        #endif
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Whether a search finds this, matching the question or the answer, ignoring case and accents.
    func matches(_ query: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return question.range(of: query, options: options) != nil
            || answer.range(of: query, options: options) != nil
    }
}
