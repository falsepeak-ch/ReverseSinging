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
                EditorScreenHeader(title: GameMode.dub.title, onBack: { dismiss() }) {
                    HStack(spacing: 10) {
                        optionsMenu

                        EditorToolbarButton(icon: "plus", label: Strings.Dub.importPack) {
                            viewModel.requestImport()
                        }
                        .disabled(library.isImporting)
                    }
                }

                if library.packs.isEmpty {
                    emptyState
                } else {
                    packList
                }
            }

            if library.isImporting {
                ProcessingIndicator(
                    message: library.importMessage,
                    progress: library.importProgress
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .dubContentGate(isPresented: $viewModel.showContentGate) { viewModel.contentGateDidConfirm() }
        // Every archive kind is pickable, not only the ones the importer can open: a file
        // the picker greys out tells the user nothing, whereas picking a .rar gets them the
        // alert that says to re-save it as a .zip or .7z.
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.folder, .zip, .sevenZipArchive, .archive],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImport(result)
        }
        .navigationDestination(item: $viewModel.selectedPack) { pack in
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
        ScrollView {
            LazyVStack(spacing: 8) {
                EditorSectionHeader(
                    title: Strings.Dub.packsSection,
                    trailing: String(format: "%02d", library.packs.count)
                )
                .padding(.bottom, 2)

                ForEach(library.packs) { pack in
                    DubPackCard(
                        pack: pack,
                        recordedCount: viewModel.recordedCount(for: pack),
                        onOpen: {
                            HapticManager.shared.impact(.light)
                            viewModel.open(pack)
                        }
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

#Preview {
    DubLibraryView(pendingImportURL: .constant(nil))
}
