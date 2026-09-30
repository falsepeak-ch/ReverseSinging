//
//  MacWorkspaceViewModel.swift
//  DubloonMac
//
//  The window: what the sidebar has selected, and the models that outlive any one workspace
//

import SwiftUI
import Combine
import AppKit

/// What the sidebar can select, and so what fills the window.
enum MacDestination: Hashable {
    case reverse
    /// A reverse-singing session from the archive, by id.
    case session(UUID)
    case imitate
    /// Home Video Dub: a clip of the user's own, voiced over.
    case homeVideo
    /// Every installed pack, as a browser.
    case dubLibrary
    /// A dub pack, by id.
    case pack(UUID)

    var mode: GameMode {
        switch self {
        case .reverse, .session: .reverse
        case .imitate: .imitate
        case .homeVideo: .homeVideo
        case .dubLibrary, .pack: .dub
        }
    }

    /// A string to remember the selection by, across launches.
    var storageKey: String {
        switch self {
        case .reverse: "reverse"
        case .session(let id): "session:\(id.uuidString)"
        case .imitate: "imitate"
        case .homeVideo: "homeVideo"
        case .dubLibrary: "dubLibrary"
        case .pack(let id): "pack:\(id.uuidString)"
        }
    }

    init?(storageKey: String) {
        let parts = storageKey.split(separator: ":", maxSplits: 1).map(String.init)
        switch parts.first {
        case "reverse": self = .reverse
        case "imitate": self = .imitate
        case "homeVideo": self = .homeVideo
        case "dubLibrary": self = .dubLibrary
        case "session": guard let id = parts.last.flatMap(UUID.init) else { return nil }; self = .session(id)
        case "pack": guard let id = parts.last.flatMap(UUID.init) else { return nil }; self = .pack(id)
        default: return nil
        }
    }
}

/// Something the user asked to delete, waiting on the confirmation.
enum MacDeletion: Identifiable {
    case pack(DubPack)
    case session(AudioSession)

    var id: String {
        switch self {
        case .pack(let pack): "pack:\(pack.id)"
        case .session(let session): "session:\(session.id)"
        }
    }
}

/// Drives the Mac window.
///
/// The Mac has no menu to push games from: the games, the packs and the archive sit side by
/// side in a sidebar, and picking one swaps the workspace. So this owns what the iPhone's menu
/// owns, the reverse game (a session survives switching away), the pack library, and the menu's
/// own model for the locked games, the paywall and the one-off notes, and adds the selection and the
/// inspector.
@MainActor
final class MacWorkspaceViewModel: ObservableObject {

    /// What the window shows. Every change goes through `select(_:)`, which asks the paywall.
    @Published private(set) var selection: MacDestination? {
        didSet {
            guard selection != oldValue else { return }
            // Remembered, so the app reopens where it was left.
            defaults.set(selection?.storageKey, forKey: Key.lastSelection)
            if case .pack(let id)? = selection { noteRecent(id) }
        }
    }

    /// One switch for every workspace, so the inspector stays where the user left it, across
    /// launches too.
    @Published var showsInspector: Bool {
        didSet { defaults.set(showsInspector, forKey: Key.showsInspector) }
    }

    /// The sidebar's search field, ⌘F.
    @Published var searchText = ""

    /// A pack or session waiting on "are you sure".
    @Published var pendingDeletion: MacDeletion?

    /// The packs open in windows of their own. A pack is edited in one place at a time: two
    /// editors on one pack would be two owners of its audio and of its takes.
    @Published private(set) var packsInWindows: Set<UUID> = []

    /// Opens a scene's window; handed over by the library window, which has one to give.
    var openWindow: OpenWindowAction?

    /// Packs opened lately, newest first, for File ▸ Open Recent.
    @Published private(set) var recentPackIDs: [UUID]

    /// A pack from Finder or the Dock that arrived while dubbing was locked. The paywall it
    /// opened decides: bought, and the pack is imported and opened; closed, and it is dropped,
    /// as on the iPhone.
    private var importAwaitingUnlock: URL?

    private let defaults = UserDefaults.standard

    private enum Key {
        static let lastSelection = "mac.lastSelection"
        static let showsInspector = "mac.showsInspector"
        static let recentPacks = "mac.recentPacks"
    }

    /// The reverse game's model, held here so a session in progress survives a trip to a pack.
    let game = ReverseGameViewModel()
    /// The installed packs, their import, and the content gate in front of it.
    let dubLibrary = DubLibraryViewModel()
    /// The iPhone menu's model: the locked games, the paywall, the review banner and the notes.
    let home = HomeViewModel()

    private var cancellables = Set<AnyCancellable>()

    init() {
        showsInspector = UserDefaults.standard.object(forKey: Key.showsInspector) as? Bool ?? true
        recentPackIDs = (UserDefaults.standard.stringArray(forKey: Key.recentPacks) ?? []).compactMap(UUID.init)

        for publisher in [game.objectWillChange, dubLibrary.objectWillChange, home.objectWillChange] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // A subscription that runs out with a paid game open closes it, as it does on the iPhone.
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

        AccessController.shared.$state
            .removeDuplicates()
            .filter { $0 != .locked }
            .sink { [weak self] _ in
                Task { @MainActor in await self?.resumeImportAwaitingUnlock() }
            }
            .store(in: &cancellables)

        // The scoring switch sits in four places on the Mac (library, editor toolbar,
        // inspector, Settings); every flip is counted once, here, as the iPhone counts its one.
        DubScoringPreference.shared.$isEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in self?.dubLibrary.scoringDidChange(enabled: enabled) }
            .store(in: &cancellables)

        home.$paywallSource
            .dropFirst()
            .filter { $0 == nil }
            .sink { [weak self] _ in
                // A moment later: a purchase closes the paywall and unlocks in either order, and the
                // store can take a beat to say so.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    guard let self else { return }
                    if self.home.isLocked(.dub) { self.importAwaitingUnlock = nil }
                }
            }
            .store(in: &cancellables)
    }

    private func resumeImportAwaitingUnlock() async {
        guard let url = importAwaitingUnlock, !home.isLocked(.dub) else { return }
        importAwaitingUnlock = nil
        await importPack(from: url)
    }

    // MARK: - Screen

    func onAppear(app: AppViewModel) {
        home.onAppear(game: game, app: app)
        dubLibrary.onAppear()
        if selection == nil { restoreSelection() }
        #if DEBUG
        applyScreenshotDestination()
        #endif
    }

    // MARK: - Selection

    /// Back to where the window was left, once the packs are known; the reverse studio if that
    /// place has gone, or is behind the paywall now.
    private func restoreSelection() {
        selection = .reverse
        #if DEBUG
        if ScreenshotMode.isActive || UserDefaults.standard.bool(forKey: "macE2E") { return }
        #endif
        guard let key = defaults.string(forKey: Key.lastSelection),
              let saved = MacDestination(storageKey: key), saved != .reverse else { return }
        Task {
            // The library loads its packs a beat after launch.
            for _ in 0..<40 where packs.isEmpty { try? await Task.sleep(for: .milliseconds(50)) }
            let exists: Bool = switch saved {
            case .pack(let id): pack(id: id) != nil
            case .session(let id): session(id: id) != nil
            default: true
            }
            if exists, !home.isLocked(saved.mode) { selection = saved }
        }
    }

    /// Every way into a workspace: the sidebar, the menus and the keyboard.
    func select(_ destination: MacDestination?) {
        guard let destination else {
            selection = nil
            return
        }
        guard destination != selection else { return }
        // Already open on its own: that window comes to the front instead.
        if case .pack(let id) = destination, packsInWindows.contains(id) {
            openInNewWindow(id)
            return
        }
        guard home.requestEntry(destination.mode) else { return }
        showLibraryWindow()
        // Leaving a take half-recorded behind is not a thing a sidebar click should do.
        game.stopPlayback()
        selection = destination
    }

    /// A binding for the sidebar's `List`, routed through the paywall.
    var selectionBinding: Binding<MacDestination?> {
        Binding(get: { self.selection }, set: { self.select($0) })
    }

    // MARK: - Windows

    /// File ▸ Open in New Window, a double-click on a pack, or its context menu: the pack in a
    /// window of its own, which the library window stops showing. The same pack again brings
    /// its window to the front.
    func openInNewWindow(_ id: UUID) {
        guard pack(id: id) != nil else { return }
        guard packsInWindows.contains(id) || home.requestEntry(.dub) else { return }
        if selection == .pack(id) { selection = .dubLibrary }
        noteRecent(id)
        openWindow?(id: MacWindowID.pack, value: id)
    }

    /// The pack the menus mean by "the selected pack".
    var selectedPackID: UUID? {
        if case .pack(let id)? = selection { return id }
        return nil
    }

    /// The menus that choose a workspace, typed with a pack's window in front, bring the
    /// library window forward, or back if it was closed.
    func showLibraryWindow() {
        if let window = NSApp.windows.first(where: { MacWindowID.isKind(MacWindowID.main, $0) }), window.isVisible {
            if !window.isKeyWindow, NSApp.isActive { window.makeKeyAndOrderFront(nil) }
        } else {
            openWindow?(id: MacWindowID.main)
        }
    }

    func packWindowDidOpen(_ id: UUID) {
        packsInWindows.insert(id)
        if selection == .pack(id) { selection = .dubLibrary }
    }

    func packWindowDidClose(_ id: UUID) {
        packsInWindows.remove(id)
    }

    func openFirstPack() {
        if let pack = dubLibrary.library.packs.first {
            select(.pack(pack.id))
        } else {
            select(.dubLibrary)
        }
    }

    /// The Help chapter for what the window shows.
    var helpTopic: HelpTopic {
        switch selection {
        case .reverse, .session: .reverse
        case .imitate: .imitate
        case .homeVideo: .homeVideo
        case .dubLibrary: .packs
        case .pack: .dub
        case nil: .gettingStarted
        }
    }

    // MARK: - Recent

    var recentPacks: [DubPack] { recentPackIDs.compactMap(pack(id:)) }

    private func noteRecent(_ id: UUID) {
        recentPackIDs = Array(([id] + recentPackIDs.filter { $0 != id }).prefix(8))
        defaults.set(recentPackIDs.map(\.uuidString), forKey: Key.recentPacks)
    }

    func clearRecents() {
        recentPackIDs = []
        defaults.removeObject(forKey: Key.recentPacks)
    }

    // MARK: - Search

    var filteredPacks: [DubPack] {
        guard !searchText.isEmpty else { return packs }
        return packs.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredSessions: [AudioSession] {
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Edit ▸ Find: the cursor in the sidebar's search field, which macOS 14's `searchable`
    /// does not bind to ⌘F by itself.
    func focusSearch() {
        #if DEBUG
        FileHandle.standardError.write(Data("FIND|called key=\(NSApp.keyWindow != nil)\n".utf8))
        #endif
        // The search field lives in the library window's sidebar, whichever window is in front.
        guard let window = NSApp.windows.first(where: { MacWindowID.isKind(MacWindowID.main, $0) }),
              let root = window.contentView?.superview else { return }
        window.makeKeyAndOrderFront(nil)
        func find(_ view: NSView) -> NSSearchField? {
            if let field = view as? NSSearchField { return field }
            for sub in view.subviews { if let hit = find(sub) { return hit } }
            return nil
        }
        if let field = find(root) {
            window.makeFirstResponder(field)
        } else {
            #if DEBUG
            func classes(_ view: NSView) -> [String] { [String(describing: type(of: view))] + view.subviews.flatMap(classes) }
            let names = Set(classes(root).filter { $0.localizedCaseInsensitiveContains("search") || $0.localizedCaseInsensitiveContains("field") })
            FileHandle.standardError.write(Data("FIND|no NSSearchField; candidates=\(names)\n".utf8))
            #endif
        }
    }

    // MARK: - Finder

    func revealInFinder(_ pack: DubPack) {
        NSWorkspace.shared.activateFileViewerSelecting([pack.directoryURL])
    }

    // MARK: - Deleting

    /// What the Delete key and the context menus ask for: the selected pack or session.
    func requestDeleteSelection() {
        switch selection {
        case .pack(let id): if let pack = pack(id: id) { pendingDeletion = .pack(pack) }
        case .session(let id): if let session = session(id: id) { pendingDeletion = .session(session) }
        default: break
        }
    }

    func confirmDeletion() {
        switch pendingDeletion {
        case .pack(let pack)?: delete(pack)
        case .session(let session)?: deleteSession(session)
        case nil: break
        }
        pendingDeletion = nil
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
        case .homeVideo: GameMode.homeVideo.title
        case .dubLibrary: GameMode.dub.title
        case .pack(let id): pack(id: id)?.title ?? GameMode.dub.title
        case nil: "Dubloon"
        }
    }

    // MARK: - Packs

    func requestImport() {
        guard home.requestEntry(.dub) else { return }
        showLibraryWindow()
        dubLibrary.requestImport()
    }

    /// Help ▸ Where to Find More Scenes, and the row under the pack browser.
    func showPackGuide() {
        showLibraryWindow()
        dubLibrary.showPackGuide = true
    }

    /// The guide's Import button: through the paywall and the content gate like any import.
    func packGuideDidRequestImport() {
        dubLibrary.showPackGuide = false
        requestImport()
    }

    func delete(_ pack: DubPack) {
        if selection == .pack(pack.id) { selection = .dubLibrary }
        recentPackIDs.removeAll { $0 == pack.id }
        defaults.set(recentPackIDs.map(\.uuidString), forKey: Key.recentPacks)
        dubLibrary.delete(pack)
    }

    /// A pack from Finder, the Dock or a drop onto the sidebar.
    func importPack(from url: URL) async {
        #if DEBUG
        FileHandle.standardError.write(Data("IMPORT|start \(url.lastPathComponent) allowed=\(!home.isLocked(.dub))\n".utf8))
        defer { FileHandle.standardError.write(Data("IMPORT|end error=\(dubLibrary.library.errorMessage ?? "none") packs=\(packs.count)\n".utf8)) }
        #endif
        guard !home.isLocked(.dub) else {
            importAwaitingUnlock = url
            home.showPaywall(from: .lockedImport)
            return
        }
        let before = Dictionary(packs.map { ($0.id, $0.importedAt) }, uniquingKeysWith: { first, _ in first })
        await dubLibrary.importPack(from: url)
        await dubLibrary.library.reloadNow()
        guard dubLibrary.library.errorMessage == nil else { return }
        // A new pack, or one that replaced an older copy of itself: either way, the one whose
        // import is newer than anything the library held before.
        let imported = packs.first { before[$0.id] == nil }
            ?? packs.filter { pack in before[pack.id].map { pack.importedAt > $0 } ?? false }
                .max { $0.importedAt < $1.importedAt }
        if let imported { selection = .pack(imported.id) }
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
