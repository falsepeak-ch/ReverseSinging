//
//  HelpViewModel.swift
//  ReverseSinging
//
//  Help: what is open, what is searched for, and the ways out to a person
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

@MainActor
final class HelpViewModel: ObservableObject {

    /// The chapter the screen that opened Help is about, shown first and opened.
    let initialTopic: HelpTopic

    @Published var query = ""
    @Published private(set) var expanded: Set<String> = []

    init(topic: HelpTopic) {
        initialTopic = topic
        // The first answer of the chapter someone came from is already open: they tapped help
        // on that screen, so it is most likely their question.
        if topic != .gettingStarted, let first = topic.articles.first {
            expanded = [first.id]
        }
    }

    // MARK: - Content

    /// The chapter asked for first, then the rest in their usual order.
    var topics: [HelpTopic] {
        [initialTopic] + HelpTopic.allCases.filter { $0 != initialTopic }
    }

    var isSearching: Bool { !trimmedQuery.isEmpty }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Every answer the search finds, across chapters.
    var searchResults: [HelpArticle] {
        HelpTopic.allCases.flatMap(\.articles).filter { $0.matches(trimmedQuery) }
    }

    func isExpanded(_ article: HelpArticle) -> Bool {
        isSearching || expanded.contains(article.id)
    }

    func toggle(_ article: HelpArticle) {
        if expanded.contains(article.id) {
            expanded.remove(article.id)
        } else {
            expanded.insert(article.id)
            AnalyticsManager.shared.trackCustomEvent(name: "help_article_opened", parameters: ["article": article.id])
        }
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "Help")
        AnalyticsManager.shared.trackCustomEvent(name: "help_opened", parameters: ["topic": initialTopic.rawValue])
    }

    // MARK: - Ways out

    var contactURL: URL? {
        AppLinks.supportMail(subject: Strings.Help.mailSubject, details: Self.deviceDetails)
    }

    func contactTapped() {
        AnalyticsManager.shared.trackCustomEvent(name: "help_contact_tapped", parameters: ["topic": initialTopic.rawValue])
    }

    /// App version and build, system version and device model: what a bug report needs first.
    private static var deviceDetails: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        #if os(iOS)
        let system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        let system = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #endif
        return "Dubloon \(version) (\(build)) · \(system) · \(machineModel)"
    }

    /// The hardware identifier, such as `iPhone17,3`: specific where `UIDevice.model` only says
    /// "iPhone".
    private static var machineModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
