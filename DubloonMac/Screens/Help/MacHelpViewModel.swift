//
//  MacHelpViewModel.swift
//  DubloonMac
//
//  The Help window: which chapter is open, what is searched for, and the way to a person
//

import SwiftUI
import Combine

/// Drives the Help window.
///
/// The questions, the search and the support mail are the iPhone's `HelpViewModel`. There
/// Help is one long sheet opened on a chapter; here it is a window with the chapters down a
/// sidebar, so opening Help from a workspace selects that workspace's chapter.
@MainActor
final class MacHelpViewModel: ObservableObject {
    static let shared = MacHelpViewModel()

    let help = HelpViewModel(topic: .gettingStarted)

    @Published var topic: HelpTopic? = .gettingStarted

    private var cancellables = Set<AnyCancellable>()

    private init() {
        help.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Help ▸ Dubloon Help, a workspace's ? button, or Settings: the window on that chapter.
    func open(_ topic: HelpTopic, with openWindow: OpenWindowAction) {
        help.query = ""
        self.topic = topic
        // The first answer of the chapter someone came from is open: it is most likely their
        // question.
        if topic != .gettingStarted, let first = topic.articles.first, !help.isExpanded(first) {
            help.toggle(first)
        }
        openWindow(id: MacWindowID.help)
        AnalyticsManager.shared.trackScreenViewed(screenName: "Help")
        AnalyticsManager.shared.trackCustomEvent(name: "help_opened", parameters: ["topic": topic.rawValue])
    }

    var articles: [HelpArticle] {
        help.isSearching ? help.searchResults : (topic?.articles ?? [])
    }

    var title: String {
        help.isSearching ? Strings.Help.title : (topic?.title ?? Strings.Help.title)
    }
}
