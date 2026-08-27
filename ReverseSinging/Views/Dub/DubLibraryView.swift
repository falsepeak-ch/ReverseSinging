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
    /// carry its own navigation stack or a Close button — the push supplies both.
    var isPushed: Bool = false

    @StateObject private var library = DubPackLibrary()
    @ObservedObject private var scoring = DubScoringPreference.shared
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
            .ignoresSafeArea(edges: .top)

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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.folder, .zip],
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
        // still ran — the importer does its work detached — but `isImporting` never stuck,
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
            // row — the only way to say what the switch does without a second screen.
            Text(Strings.Dub.Score.settingDetail)
        }
        .onChange(of: scoring.isEnabled) { _, enabled in
            HapticManager.shared.light()
            AnalyticsManager.shared.trackDubScoringToggled(enabled: enabled)
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

    /// Asked every time. The gate is not a consent checkbox to be got past once —
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

// MARK: - Progress Bar

/// One tick per line, filled as takes land. At 62 lines this reads as a filmstrip
/// filling up, which is far more informative than a percentage bar.
struct DubProgressBar: View {
    let recorded: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                let ticks = min(total, 40)
                let spacing: CGFloat = 2
                let width = max(1, (geometry.size.width - spacing * CGFloat(ticks - 1)) / CGFloat(ticks))
                let filled = total > 0 ? Int((Double(recorded) / Double(total)) * Double(ticks)) : 0

                HStack(spacing: spacing) {
                    ForEach(0..<ticks, id: \.self) { index in
                        Rectangle()
                            .fill(index < filled ? Color.rsGood : Color.rsSurface3)
                            .frame(width: width, height: 4)
                    }
                }
            }
            .frame(height: 4)

            Text("\(recorded)/\(total)")
                .font(.rsTimecodeSmall)
                .foregroundColor(recorded == total && total > 0 ? .rsGood : .rsTextTertiary)
        }
    }
}

// MARK: - Still Image

/// Loads a pack still off the main thread and keeps it decoded for the view's lifetime.
struct DubStillImage: View {
    let url: URL
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        // The image goes in an overlay rather than a ZStack sibling: an aspect-fill image is
        // wider than its frame, and as a ZStack child it would size the stack — and anything
        // laid out over it — past the screen edge.
        Color.black
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            }
            .clipped()
            .task(id: url) {
                guard image == nil else { return }
                let path = url.path
                image = await Task.detached(priority: .userInitiated) {
                    UIImage(contentsOfFile: path)
                }.value
            }
    }
}

#Preview {
    DubLibraryView(pendingImportURL: .constant(nil))
}
