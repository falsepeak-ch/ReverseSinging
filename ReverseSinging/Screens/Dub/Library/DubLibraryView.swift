//
//  DubLibraryView.swift
//  ReverseSinging
//
//  The list of dub packs installed on this device
//

import SwiftUI
import UniformTypeIdentifiers

struct DubLibraryView: View {
    /// A pack handed to the app from outside (AirDrop, "Open with"), imported on appear.
    @Binding var pendingImportURL: URL?

    /// True when this screen was pushed from the game menu, in which case it must not
    /// carry its own navigation stack or a Close button. The push supplies both.
    var isPushed: Bool = false

    @StateObject private var viewModel = DubLibraryViewModel()
    @ObservedObject private var scoring = DubScoringPreference.shared
    @ObservedObject private var booth = BoothCamPreference.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Width of the library's area, measured, so the split only appears when each pane
    /// gets a usable width (not in a narrow Stage Manager window that is still regular).
    @State private var availableWidth: CGFloat = 0

    /// A fold runs across the screen (iPhone Duo half folded as a table): the split stacks
    /// the list over the detail, one pane on each side of the fold.
    @State private var hasHorizontalFold = false
    /// The list's share of the split: half the window (see `readWindowMiddleRatio`).
    @State private var splitRatio: CGFloat = 0.5

    /// The packs, their import and its errors. Its changes reach this screen through
    /// `viewModel`, which passes them on.
    private var library: DubPackLibrary { viewModel.library }

    var body: some View {
        // Pushed from the menu it inherits that stack; presented as a sheet it needs
        // one of its own.
        Group {
            if isPushed {
                content
            } else {
                NavigationStack { content }
            }
        }
    }

    private var content: some View {
        ZStack {
            Color.rsSurface0
                .ignoresSafeArea()
                .filmGrain()

            // Same header as the reverse-singing screen: back, the mode's own
            // title, its actions. Both games are pushed, so both name themselves.
            VStack(spacing: 0) {
                EditorScreenHeader(title: GameMode.dub.title, onBack: { dismiss() }, help: .dub) {
                    optionsMenu

                    EditorToolbarButton(icon: "plus", label: Strings.Dub.importPack) {
                        viewModel.requestImport()
                    }
                    .disabled(library.isImporting)
                }

                if library.packs.isEmpty {
                    emptyState
                    guideRow
                } else if isSplit, let pack = splitSelection {
                    splitBody(detail: pack)
                } else {
                    packList
                    guideRow
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            .onGeometryChange(for: Bool.self) { $0.horizontalFold != nil } action: { hasHorizontalFold = $0 }

            if library.isImporting {
                ProcessingIndicator(
                    message: library.importMessage,
                    progress: library.importProgress
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .hidesNavigationBar()
        .editorModal(isPresented: $viewModel.showPackGuide) {
            DubPackGuideModal(
                source: .example,
                onImport: viewModel.packGuideDidRequestImport,
                onClose: { viewModel.showPackGuide = false }
            )
        }
        .dubContentGate(isPresented: $viewModel.showContentGate) { viewModel.contentGateDidConfirm() }
        // Every archive kind is pickable, not only the ones the importer can open: a file
        // the picker greys out tells the user nothing, whereas picking a .rar gets them the
        // alert that says to re-save it as a .zip or .7z.
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.folder, .zip, .sevenZipArchive, .rarArchive, .archive],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImport(result)
        }
        // In the split the selection drives the second pane, not a push. The setter is
        // ignored there too, so opening the device (compact to regular) never clears the
        // selection by popping the pushed detail: the same pack moves into the pane.
        .navigationDestination(item: Binding(
            get: { isSplit ? nil : viewModel.selectedPack },
            set: { if !isSplit { viewModel.selectedPack = $0 } }
        )) { pack in
            DubPackDetailView(pack: pack, library: library)
        }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
        .onAppear { viewModel.onAppear() }
        #if DEBUG
        .task { await viewModel.seedScreenshotTakes() }
        #endif
        // Clear the URL *after* importing, never before: `pendingImportURL` is this task's
        // id, so nilling it first cancels the task that is about to do the work. The import
        // still ran. The importer does its work detached. But `isImporting` never stuck,
        // so a multi-minute conversion showed no progress at all and looked like a hang.
        .task(id: pendingImportURL) {
            guard let url = pendingImportURL else { return }
            await viewModel.importPack(from: url)
            pendingImportURL = nil
        }
        .animation(.rsSpring, value: library.isImporting)
        .animation(reduceMotion ? nil : .rsSmooth, value: isSplit)
        .animation(reduceMotion ? nil : .rsSmooth, value: splitSelection?.id)
    }

    // MARK: - Split (regular size)

    /// List and detail side by side: iPhone Duo open, iPad full screen, a wide window.
    private var isSplit: Bool {
        sizeClass == .regular && verticalSizeClass == .regular
            && (availableWidth >= 700 || (hasHorizontalFold && !dynamicTypeSize.isAccessibilitySize))
    }

    /// The pack in the second pane: the one last opened, else the first. Looked up by id so
    /// a deleted pack falls back rather than lingering.
    private var splitSelection: DubPack? {
        if let id = viewModel.selectedPack?.id, let pack = library.packs.first(where: { $0.id == id }) {
            return pack
        }
        return library.packs.first
    }

    @ViewBuilder
    private func splitBody(detail pack: DubPack) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            // Side by side in either orientation, with equal panes, so the fold of a
            // book pose falls between the list and the detail rather than through either.
            // Half folded as a table, the list above the fold and the detail below it.
            ArrangementView {
                splitList
                    .splitArrangementLayoutRatio(splitRatio)
            } secondary: {
                splitDetail(pack)
            }
            .arrangementViewStyle(.split.axes(hasHorizontalFold ? .vertical : .horizontal))
            // Open flat, the status strip narrows the trailing side: halves of the window,
            // not of the safe area, so the divide is on the seam.
            .readWindowMiddleRatio(into: $splitRatio)
        } else {
            splitStack(detail: pack)
        }
        #else
        splitStack(detail: pack)
        #endif
    }

    /// Before iOS 27.1 (iPad): the same two equal panes.
    private func splitStack(detail pack: DubPack) -> some View {
        HStack(spacing: 0) {
            splitList
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(Color.rsStroke)
                .frame(width: EditorMetrics.hairline)
            splitDetail(pack)
                .frame(maxWidth: .infinity)
        }
    }

    private var splitList: some View {
        VStack(spacing: 0) {
            packScroll(columns: [GridItem(.flexible(), spacing: 8)], selected: splitSelection?.id)
            guideRow
        }
    }

    private func splitDetail(_ pack: DubPack) -> some View {
        DubPackDetailView(pack: pack, library: library, showsBack: false)
            // A new model per pack: the detail's state belongs to the pack it shows.
            .id(pack.id)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
    }

    /// Pinned under the list rather than scrolled with it, so the way to more
    /// scenes is on screen however many are already in.
    private var guideRow: some View {
        DubPackGuideRow { viewModel.showPackGuide = true }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }

    // MARK: - Options

    /// The dub mode's own settings, kept here rather than in the app's Settings screen: they
    /// only mean anything inside this game, and this is where the user already is when they
    /// decide they want them.
    private var optionsMenu: some View {
        EditorToolbarMenu(icon: "slider.horizontal.3", label: Strings.Dub.options) {
            Toggle(isOn: $scoring.isEnabled) {
                Label(Strings.Dub.Score.settingTitle, systemImage: "chart.bar.fill")
            }

            // Menus give a footer no styling of its own, so the explanation is a plain
            // row. The only way to say what the switch does without a second screen.
            Text(Strings.Dub.Score.settingDetail)

            Divider()

            // The same switch as the one in Settings and the key in the record HUD; this is
            // just the copy of it that is nearest to hand when you are already in the game.
            if viewModel.canToggleBooth {
                Toggle(isOn: $booth.isEnabled) {
                    Label(Strings.Booth.settingsTitle, systemImage: "video.fill")
                }

                Text(Strings.Booth.settingsDesc)
            }
        }
        .onChange(of: scoring.isEnabled) { _, enabled in
            viewModel.scoringDidChange(enabled: enabled)
        }
        .onChange(of: booth.isEnabled) { _, enabled in
            viewModel.boothDidChange(enabled: enabled)
        }
    }

    // MARK: - Pack List

    private var packList: some View {
        packScroll(columns: ReadableColumns.columns(for: sizeClass, spacing: 8, dynamicTypeSize: dynamicTypeSize), selected: nil)
    }

    private func packScroll(columns: [GridItem], selected: DubPack.ID?) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                EditorSectionHeader(
                    title: Strings.Dub.packsSection,
                    trailing: String(format: "%02d", library.packs.count)
                )
                .padding(.bottom, 2)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(library.packs) { pack in
                        DubPackCard(
                            pack: pack,
                            recordedCount: viewModel.recordedCount(for: pack),
                            onOpen: {
                                HapticManager.shared.impact(.light)
                                viewModel.open(pack)
                            },
                            prominent: selected == nil && sizeClass == .regular && verticalSizeClass == .regular,
                            isSelected: pack.id == selected
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.delete(pack)
                            } label: {
                                Label(Strings.Dub.delete, systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Image("clapperboard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleIn(delay: 0.05)

                VStack(spacing: 8) {
                    Text(Strings.Dub.emptyTitle)
                        .font(.rsHeadingSmall)
                        .foregroundColor(.rsTextPrimary)

                    Text(Strings.Dub.emptyMessage)
                        .font(.rsBodySmall)
                        .foregroundColor(.rsTextTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 40)
                }
            }
            .fadeIn(delay: 0.1)

            BigButton(
                title: Strings.Dub.importPack,
                icon: "square.and.arrow.down",
                color: .rsTextPrimary,
                action: viewModel.requestImport,
                style: .primary
            )
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .fadeIn(delay: 0.2)

            Spacer()
        }
    }
}

#Preview("iPhone") {
    DubLibraryView(pendingImportURL: .constant(nil))
}

#Preview("Duo open, portrait (book)", traits: .fixedLayout(width: 1003, height: 1427)) {
    DubLibraryView(pendingImportURL: .constant(nil))
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .regular)
}

#Preview("Duo open, landscape", traits: .fixedLayout(width: 1427, height: 1003)) {
    DubLibraryView(pendingImportURL: .constant(nil))
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .regular)
}
