//
//  MacPackWindow.swift
//  DubloonMac
//
//  One dub pack in a window of its own
//

import SwiftUI

/// A pack opened on its own, the way a document opens in its own window: the same editor the
/// library window shows, with its own transport, inspector and sheets, so two packs can sit
/// side by side and the menus act on whichever is in front.
struct MacPackWindow: View {
    let packID: UUID?
    @ObservedObject var workspace: MacWorkspaceViewModel

    @Environment(\.dismiss) private var dismiss
    /// Pack windows share one inspector setting, apart from the library window's.
    @AppStorage("mac.packWindow.showsInspector") private var showsInspector = true

    private var pack: DubPack? { packID.flatMap(workspace.pack(id:)) }

    var body: some View {
        Group {
            if let pack {
                DubEditorView(pack: pack, library: workspace.dubLibrary.library, showsInspector: $showsInspector)
                    .id(pack.id)
                    .navigationTitle(pack.title)
            } else {
                EmptyWorkspaceView()
            }
        }
        .frame(minWidth: 1000, minHeight: 640)
        .preferredColorScheme(.dark)
        .onAppear {
            if let packID { workspace.packWindowDidOpen(packID) }
        }
        .onDisappear {
            if let packID { workspace.packWindowDidClose(packID) }
        }
        // A pack deleted from the library, or a subscription that runs out, takes its window with it.
        .onChange(of: pack == nil) { _, isGone in if isGone { dismiss() } }
        .onChange(of: workspace.home.isLocked(.dub)) { _, isLocked in if isLocked { dismiss() } }
    }
}
