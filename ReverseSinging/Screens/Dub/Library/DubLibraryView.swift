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

    @StateObject private var library = DubPackLibrary()
    @ObservedObject private var scoring = DubScoringPreference.shared
    @ObservedObject private var booth = BoothCamPreference.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showFileImporter = false
    @State private var showContentGate = false
    @State private var selectedPack: DubPack?

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
                            requestImport()
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
        // Beyond the starter scenes the app hosts nothing, so every import is the
        // moment to ask where the user's own came from.
        .dubContentGate(isPresented: $showContentGate) { showFileImporter = true }
        // Every archive kind is pickable, not only the ones the importer can open: a file
        // the picker greys out tells the user nothing, whereas picking a .rar gets them the
        // alert that says to re-save it as a .zip or .7z.
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.folder, .zip, .sevenZipArchive, .archive],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .navigationDestination(item: $selectedPack) { pack in
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
        .onAppear {
            library.reload()
            AnalyticsManager.shared.trackScreenViewed(screenName: "DubLibrary")
        }
        #if DEBUG
        // The pack itself is copied into Documents/DubPacks by capture.sh; the takes
        // have to be written here, because they are keyed by the id the parser hands
        // the pack on this launch.
        //
        // Waiting on the reload `DubPackLibrary.init` already started, rather than
        // calling `reloadNow()` again: an unimported pack has no manifest yet, so two
        // concurrent loads each parse it and each mint a different pack id. Takes
        // seeded against one id are invisible to the other, which is exactly how the
        // record screen came out reading 0 dubbed with seven takes on disk.
        .task {
            guard ScreenshotMode.isActive else { return }

            var waited = 0
            while library.packs.isEmpty && waited < 120 {
                try? await Task.sleep(for: .milliseconds(80))
                waited += 1
            }
            guard let pack = library.packs.first else { return }

            ScreenshotMode.seedTakes(for: pack)
            await library.reloadNow()

            if ScreenshotMode.destination?.opensPack == true {
                // The app preview opens here, so the library needs a beat on screen
                // before the push. A still frame doesn't.
                if ScreenshotMode.destination?.isTour == true {
                    try? await Task.sleep(for: .seconds(ScreenshotMode.Tour.libraryHold))
                }
                selectedPack = library.packs.first { $0.id == pack.id } ?? pack
            }
        }
        #endif
        // Clear the URL *after* importing, never before: `pendingImportURL` is this task's
        // id, so nilling it first cancels the task that is about to do the work. The import
        // still ran. The importer does its work detached. But `isImporting` never stuck,
        // so a multi-minute conversion showed no progress at all and looked like a hang.
        .task(id: pendingImportURL) {
            guard let url = pendingImportURL else { return }
            await library.importPack(from: url)
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
            // Offered only once the camera has been granted: the explanation the first "yes"
            // deserves does not fit in a menu row.
            if BoothRecorder.cameraPermission == .granted {
                Toggle(isOn: $booth.isEnabled) {
                    Label(Strings.Booth.settingsTitle, systemImage: "video.fill")
                }

                Text(Strings.Booth.settingsDesc)
            }
        }
        .onChange(of: scoring.isEnabled) { _, enabled in
            HapticManager.shared.light()
            AnalyticsManager.shared.trackDubScoringToggled(enabled: enabled)
        }
        .onChange(of: booth.isEnabled) { _, enabled in
            HapticManager.shared.light()
            AnalyticsManager.shared.trackCustomEvent(
                name: enabled ? "booth_cam_enabled" : "booth_cam_disabled",
                parameters: nil
            )
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
                        recordedCount: library.recordedCount(for: pack),
                        onOpen: {
                            HapticManager.shared.impact(.light)
                            selectedPack = pack
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            library.delete(pack)
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
                action: requestImport,
                style: .primary
            )
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .fadeIn(delay: 0.2)

            Spacer()
        }
    }

    // MARK: - Import

    /// Asked every time. The gate is not a consent checkbox to be got past once,
    /// it is where the app says it hosts nothing, where the rights disclaimer
    /// lives, and the only route to "where do these files come from". Remembering
    /// a yes hid all three from everyone who had already answered.
    private func requestImport() {
        showContentGate = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await library.importPack(from: url) }
        case .failure(let error):
            library.errorMessage = error.localizedDescription
            // The picker itself failed, so no import ever started and neither the import
            // events nor `DubPackLibrary`'s non-fatal will ever mention it. From the user's
            // side this is indistinguishable from a pack that would not open.
            CrashReporter.shared.record(error, context: "dub_pack.file_picker")
        }
    }
}

// MARK: - Pack Card

struct DubPackCard: View {
    let pack: DubPack
    let recordedCount: Int
    /// Tapping anywhere on the card opens the pack.
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 0) {
                thumbnail
                info
            }
        }
        .buttonStyle(.plain)
        .frame(height: 74)
        .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
        .editorPanel()
    }

    /// 16:9 thumbnail, like a clip in a bin.
    private var thumbnail: some View {
        DubStillImage(url: pack.iconURL)
            .frame(width: 112, height: 74)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.rsStroke)
                    .frame(width: EditorMetrics.hairline)
            }
            .contentShape(Rectangle())
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(pack.title)
                .font(.rsButtonSmall)
                .foregroundColor(.rsTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                Text(pack.formattedDuration)
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextSecondary)

                Text("·")
                    .foregroundColor(.rsTextTertiary)

                Text(pack.authorsDescription)
                    .font(.rsMeta)
                    .foregroundColor(.rsTextTertiary)
                    .lineLimit(1)
            }

            DubProgressBar(recorded: recordedCount, total: pack.lines.count)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview {
    DubLibraryView(pendingImportURL: .constant(nil))
}
