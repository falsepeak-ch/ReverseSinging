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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showFileImporter = false
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
                    EditorToolbarButton(icon: "plus", label: Strings.Dub.importPack) {
                        showFileImporter = true
                    }
                    .disabled(library.isImporting)
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
                    Button {
                        HapticManager.shared.impact(.light)
                        selectedPack = pack
                    } label: {
                        DubPackCard(
                            pack: pack,
                            recordedCount: library.recordedCount(for: pack)
                        )
                    }
                    .buttonStyle(.plain)
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
                action: { showFileImporter = true },
                style: .primary
            )
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .fadeIn(delay: 0.2)

            Spacer()
        }
    }

    // MARK: - Import

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

    var body: some View {
        HStack(spacing: 0) {
            // 16:9 thumbnail, like a clip in a bin
            DubStillImage(url: pack.iconURL)
                .frame(width: 112, height: 74)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.rsStroke)
                        .frame(width: EditorMetrics.hairline)
                }

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
        }
        .frame(height: 74)
        .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
        .editorPanel()
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
