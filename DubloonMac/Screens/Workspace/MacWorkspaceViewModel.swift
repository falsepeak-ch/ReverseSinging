//
//  MacWorkspaceViewModel.swift
//  DubloonMac
//
//  The window: what the sidebar has selected, and the models that outlive any one workspace
//

import SwiftUI
import Combine

/// What the sidebar can select, and so what fills the window.
enum MacDestination: Hashable {
    case reverse
    /// A reverse-singing session from the archive, by id.
    case session(UUID)
    case imitate
    /// Every installed pack, as a browser.
    case dubLibrary
    /// A dub pack, by id.
    case pack(UUID)

    var mode: GameMode {
        switch self {
        case .reverse, .session: .reverse
        case .imitate: .imitate
        case .dubLibrary, .pack: .dub
        }
    }
}

/// Drives the Mac window.
///
/// The Mac has no menu to push games from: the games, the packs and the archive sit side by
/// side in a sidebar, and picking one swaps the workspace. So this owns what the iPhone's menu
/// owns, the reverse game (a session survives switching away), the pack library, and the menu's
/// own model for the trial, the paywall and the one-off notes, and adds the selection and the
/// inspector.
@MainActor
final class MacWorkspaceViewModel: ObservableObject {

    /// What the window shows. Every change goes through `select(_:)`, which asks the paywall.
    @Published private(set) var selection: MacDestination? {
        // Cleared on every swap; the incoming workspace publishes its own as it appears.
        didSet { if selection != oldValue { transport = MacTransport() } }
    }

    /// One switch for every workspace, so the inspector stays where the user left it.
    @Published var showsInspector = true

    /// What the Playback menu can do in the workspace on screen. See `publishesTransport`.
    @Published var transport = MacTransport()

    /// The reverse game's model, held here so a session in progress survives a trip to a pack.
    let game = ReverseGameViewModel()
    /// The installed packs, their import, and the content gate in front of it.
    let dubLibrary = DubLibraryViewModel()
    /// The iPhone menu's model: the trial, the paywall, the review banner and the notes.
    let home = HomeViewModel()

    private var cancellables = Set<AnyCancellable>()

    init() {
        for publisher in [game.objectWillChange, dubLibrary.objectWillChange, home.objectWillChange] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // A trial that runs out with a paid game open closes it, as it does on the iPhone.
        AccessController.shared.$state
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self, state == .locked, let selection = self.selection else { return }
                // Read on the next turn: `isLocked` has not changed yet when the sink fires.
                Task { @MainActor in
                    if self.home.isLocked(selection.mode) { self.selection = nil }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Screen

    func onAppear(app: AppViewModel) {
        home.onAppear(game: game, app: app)
        dubLibrary.onAppear()
        if selection == nil { selection = .reverse }
        #if DEBUG
        applyScreenshotDestination()
        #endif
    }

    // MARK: - Selection

    /// Every way into a workspace: the sidebar, the menus and the keyboard.
    func select(_ destination: MacDestination?) {
        guard let destination else {
            selection = nil
            return
        }
        guard destination != selection else { return }
        guard home.requestEntry(destination.mode) else { return }
        // Leaving a take half-recorded behind is not a thing a sidebar click should do.
        game.stopPlayback()
        selection = destination
    }

    /// A binding for the sidebar's `List`, routed through the paywall.
    var selectionBinding: Binding<MacDestination?> {
        Binding(get: { self.selection }, set: { self.select($0) })
    }

    func openFirstPack() {
        if let pack = dubLibrary.library.packs.first {
            select(.pack(pack.id))
        } else {
            select(.dubLibrary)
        }
    }

    // MARK: - Lookups

    var packs: [DubPack] { dubLibrary.library.packs }

    var sessions: [AudioSession] { game.appState.savedSessions }

    func pack(id: UUID) -> DubPack? {
        packs.first { $0.id == id }
    }

    func session(id: UUID) -> AudioSession? {
        sessions.first { $0.id == id }
    }

    var title: String {
        switch selection {
        case .reverse, .session: GameMode.reverse.title
        case .imitate: GameMode.imitate.title
        case .dubLibrary: GameMode.dub.title
        case .pack(let id): pack(id: id)?.title ?? GameMode.dub.title
        case nil: "Dubloon"
        }
    }

    // MARK: - Packs

    func requestImport() {
        guard home.requestEntry(.dub) else { return }
        dubLibrary.requestImport()
    }

    func delete(_ pack: DubPack) {
        if selection == .pack(pack.id) { selection = .dubLibrary }
        dubLibrary.delete(pack)
    }

    /// A pack from Finder, the Dock or a drop onto the sidebar.
    func importPack(from url: URL) async {
        guard home.requestEntry(.dub) else { return }
        let known = Set(packs.map(\.id))
        await dubLibrary.importPack(from: url)
        await dubLibrary.library.reloadNow()
        if let added = packs.first(where: { !known.contains($0.id) }) {
            selection = .pack(added.id)
        }
    }

    // MARK: - Sessions

    func newSession() {
        game.startNewSession()
        select(.reverse)
    }

    func deleteSession(_ session: AudioSession) {
        if selection == .session(session.id) { selection = .reverse }
        game.deleteSession(session)
    }

    // MARK: - Screenshots

    #if DEBUG
    private func applyScreenshotDestination() {
        // `-macDestination imitate`: the one workspace the shared destinations have no name for.
        if ScreenshotMode.isActive, UserDefaults.standard.string(forKey: "macDestination") == "imitate" {
            selection = .imitate
            return
        }
        guard ScreenshotMode.isActive, let destination = ScreenshotMode.destination else { return }
        if destination.opensDubGame {
            Task {
                await dubLibrary.seedScreenshotTakes()
                if let pack = packs.first { selection = .pack(pack.id) }
            }
        } else if destination.opensReverseGame {
            selection = .reverse
        }
    }
    #endif
}
