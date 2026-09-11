//
//  SessionListViewModel.swift
//  ReverseSinging
//
//  The archive of saved reverse-singing sessions
//

import SwiftUI
import Combine

/// Drives the session archive.
///
/// The sessions belong to the game, so this reads and deletes them through
/// `ReverseGameViewModel`, and passes its changes on as this model's own.
@MainActor
final class SessionListViewModel: ObservableObject {

    /// The game whose sessions these are. Handed to the rows, which play recordings through it.
    let game: ReverseGameViewModel

    private var cancellables = Set<AnyCancellable>()

    init(game: ReverseGameViewModel) {
        self.game = game

        game.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var sessions: [AudioSession] { game.appState.savedSessions }

    var title: String { sessions.isEmpty ? "" : Strings.SessionList.title }

    /// The theme the user picked, or the system's when they left it on system.
    func effectiveColorScheme(system: ColorScheme) -> ColorScheme {
        switch game.appState.themeMode {
        case .system:
            return system
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch game.appState.themeMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackSessionListViewed(sessionsCount: sessions.count)
        AnalyticsManager.shared.trackScreenViewed(screenName: "SessionListView")
    }

    // MARK: - Actions

    func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = game.appState.savedSessions[index]
            game.deleteSession(session)
        }
    }
}
