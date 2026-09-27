//
//  MacWorkspaceView.swift
//  DubloonMac
//
//  The window: a library sidebar, and the workspace for whatever it has selected
//

import SwiftUI
import UniformTypeIdentifiers

/// The Mac window, laid out like an editing suite: libraries down the left, the workspace
/// filling the rest, each workspace bringing its own viewer, timeline and inspector.
struct MacWorkspaceView: View {
    @ObservedObject var app: AppViewModel
    @ObservedObject var workspace: MacWorkspaceViewModel
    @Environment(\.openURL) private var openURL

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var library: DubPackLibrary { workspace.dubLibrary.library }
    private var home: HomeViewModel { workspace.home }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MacSidebar(workspace: workspace)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 340)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.rsSurface0)
                .clipped()
        }
        .navigationTitle(workspace.title)
        .onAppear { workspace.onAppear(app: app) }
        // Import: the gate says its piece every time, then the picker.
        .dubContentGate(isPresented: Binding(
            get: { workspace.dubLibrary.showContentGate },
            set: { workspace.dubLibrary.showContentGate = $0 }
        )) {
            workspace.dubLibrary.contentGateDidConfirm()
        }
        .fileImporter(
            isPresented: Binding(
                get: { workspace.dubLibrary.showFileImporter },
                set: { workspace.dubLibrary.showFileImporter = $0 }
            ),
            allowedContentTypes: [.folder, .zip, .sevenZipArchive, .rarArchive, .archive],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                workspace.dubLibrary.handleImport(result)
                return
            }
            Task { await workspace.importPack(from: url) }
        }
        .macProgressSheet(
            isPresented: library.isImporting,
            image: "download",
            title: MacStrings.Menu.importPack.replacingOccurrences(of: "…", with: ""),
            message: library.importMessage,
            progress: library.importProgress > 0 ? library.importProgress : nil
        )
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
        // A pack handed over by Finder or the Dock.
        .task(id: app.pendingDubImportURL) {
            guard let url = app.pendingDubImportURL else { return }
            await workspace.importPack(from: url)
            app.pendingDubImportURL = nil
        }
        .onChange(of: app.showDubLibrary) { _, wants in
            guard wants else { return }
            app.showDubLibrary = false
        }
        // The menu's paywall and notes, as sheets on the window.
        .sheet(item: Binding(get: { home.paywallSource }, set: { home.paywallSource = $0 })) { source in
            ProPaywallView(source: source.rawValue)
        }
        .sheet(isPresented: Binding(
            get: { home.isEarlyAdopterWelcomePresented },
            set: { home.isEarlyAdopterWelcomePresented = $0 }
        )) {
            EarlyAdopterWelcomeView()
                .frame(width: 480, height: 600)
                .onDisappear { home.earlyAdopterWelcomeDidDisappear() }
        }
        .sheet(isPresented: Binding(
            get: { home.isBoothAnnouncementPresented },
            set: { home.isBoothAnnouncementPresented = $0 }
        )) {
            BoothCamAnnouncementView(onTryIt: { workspace.openFirstPack() })
                .frame(width: 480, height: 640)
                .onDisappear { home.boothAnnouncementDidDisappear() }
        }
        .sheet(isPresented: $workspace.showsShortcuts) {
            MacShortcutsView()
        }
        // Delete asks first: a pack takes its takes and footage with it.
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(
                get: { workspace.pendingDeletion != nil },
                set: { if !$0 { workspace.pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(Strings.Dub.delete, role: .destructive) { workspace.confirmDeletion() }
            Button(Strings.Main.Alert.cancel, role: .cancel) { workspace.pendingDeletion = nil }
        } message: {
            Text(deletionMessage)
        }
        .onChange(of: home.shouldWelcomeEarlyAdopter, initial: true) { _, _ in
            home.presentEarlyAdopterWelcomeIfDue()
        }
    }

    // MARK: - Deletion

    private var deletionTitle: String {
        switch workspace.pendingDeletion {
        case .pack(let pack)?: String(format: MacStrings.Confirm.deletePackTitle, pack.title)
        case .session?: MacStrings.Confirm.deleteSessionTitle
        case nil: ""
        }
    }

    private var deletionMessage: String {
        switch workspace.pendingDeletion {
        case .pack?: MacStrings.Confirm.deletePackMessage
        case .session?: MacStrings.Confirm.deleteSessionMessage
        case nil: ""
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch workspace.selection {
        case .reverse:
            ReverseStudioView(game: workspace.game, workspace: workspace, archived: nil)
                .id("reverse")
        case .session(let id):
            if let session = workspace.session(id: id) {
                ReverseStudioView(game: workspace.game, workspace: workspace, archived: session)
                    .id(id)
            } else {
                EmptyWorkspaceView()
            }
        case .imitate:
            ImitateStudioView(workspace: workspace)
        case .dubLibrary:
            DubLibraryBrowserView(workspace: workspace)
        case .pack(let id):
            if let pack = workspace.pack(id: id) {
                DubEditorView(pack: pack, library: library, workspace: workspace)
                    // A different pack is a different project: nothing carries over.
                    .id(pack.id)
            } else {
                EmptyWorkspaceView()
            }
        case nil:
            EmptyWorkspaceView()
        }
    }
}

// MARK: - Empty

struct EmptyWorkspaceView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image("icon-lettering")
                .resizable()
                .scaledToFit()
                .frame(height: 54)
                .opacity(0.85)

            Text(MacStrings.Panel.emptyTitle)
                .font(.rsHeadingSmall)
                .foregroundColor(.rsTextPrimary)

            Text(MacStrings.Panel.emptyMessage)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rsSurface0)
    }
}
