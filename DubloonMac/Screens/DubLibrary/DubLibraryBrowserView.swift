//
//  DubLibraryBrowserView.swift
//  DubloonMac
//
//  Movie Scene Dub's own page: every installed pack as a clip in a bin, and the way to add more
//

import SwiftUI

/// What opens when Movie Scene Dub itself is picked in the sidebar: the packs as a browser of
/// thumbnails, the way an editor shows the clips in an event. A pack opens in the editor; the
/// last tile imports another.
struct DubLibraryBrowserView: View {
    @ObservedObject var workspace: MacWorkspaceViewModel
    @ObservedObject private var scoring = DubScoringPreference.shared

    private let columns = [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 18)]

    private var library: DubLibraryViewModel { workspace.dubLibrary }

    var body: some View {
        VStack(spacing: 0) {
            ProPanelHeader(title: Strings.Dub.packsSection, subtitle: String(format: "%02d", workspace.packs.count))

            if workspace.packs.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(workspace.packs) { pack in
                            tile(for: pack)
                        }
                        importTile
                    }
                    .padding(22)
                }
            }
        }
        .background(Color.rsSurface0)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $scoring.isEnabled) {
                    Label(Strings.Dub.Score.settingTitle, systemImage: "chart.bar.fill")
                }
                .help(Strings.Dub.Score.settingDetail)

                Button {
                    workspace.requestImport()
                } label: {
                    Label(MacStrings.Menu.importPack, systemImage: "plus")
                }
                .help(MacStrings.Menu.importPack)
                .disabled(library.library.isImporting)
            }
        }
        .onAppear { library.onAppear() }
    }

    // MARK: - Tiles

    private func tile(for pack: DubPack) -> some View {
        let recorded = library.recordedCount(for: pack)
        let total = max(pack.lines.count, 1)

        return Button {
            // ⌥-click opens the pack in a window of its own.
            if NSEvent.modifierFlags.contains(.option) {
                workspace.openInNewWindow(pack.id)
            } else {
                workspace.select(.pack(pack.id))
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                DubStillImage(url: pack.iconURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .overlay(alignment: .bottomLeading) {
                        Text(pack.formattedDuration)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.65)))
                            .padding(6)
                    }

                Text(pack.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.rsSurface3)
                            Capsule()
                                .fill(recorded == pack.lines.count ? Color.rsGood : Color.rsHighlight)
                                .frame(width: geometry.size.width * CGFloat(recorded) / CGFloat(total))
                        }
                    }
                    .frame(height: 3)

                    Text("\(recorded)/\(pack.lines.count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.rsTextTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ProPressStyle())
        .proHoverLift()
        .contextMenu {
            Button(MacStrings.Menu.open) { workspace.select(.pack(pack.id)) }
            Button(MacStrings.Menu.openInNewWindow) { workspace.openInNewWindow(pack.id) }
            Button(MacStrings.Menu.showInFinder) { workspace.revealInFinder(pack) }
            Divider()
            Button(MacStrings.Menu.deleteEllipsis, role: .destructive) { workspace.pendingDeletion = .pack(pack) }
        }
        .help(pack.title)
    }

    /// Built like a pack's tile, so the grid keeps one rhythm: a frame, a title, a footer.
    private var importTile: some View {
        Button {
            workspace.requestImport()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.rsSurface1)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.rsStrokeStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .light))
                            .foregroundColor(.rsTextSecondary)
                    }

                Text(MacStrings.Menu.importPack)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rsTextSecondary)
                    .lineLimit(1)

                Text(verbatim: ".zip · .7z · .rar")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.rsTextTertiary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ProPressStyle())
        .proHoverLift()
        .disabled(library.library.isImporting)
        .help(Strings.Dub.emptyMessage)
    }

    // MARK: - Empty

    private var empty: some View {
        VStack(spacing: 16) {
            Image("clapperboard")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)

            Text(Strings.Dub.emptyTitle)
                .font(.rsHeadingSmall)
                .foregroundColor(.rsTextPrimary)

            Text(Strings.Dub.emptyMessage)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button(MacStrings.Menu.importPack) { workspace.requestImport() }
                .platformProminentButton()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
