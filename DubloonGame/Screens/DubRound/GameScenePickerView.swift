//
//  GameScenePickerView.swift
//  DubloonGame
//
//  Movie Scene Dub's level select: a card per scene, with how much of it is dubbed.
//

import SwiftUI
import UniformTypeIdentifiers

struct GameScenePickerView: View {
    @Binding var pendingImportURL: URL?
    @StateObject private var viewModel = DubLibraryViewModel()
    @Environment(\.dismiss) private var dismiss

    private var library: DubPackLibrary { viewModel.library }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(library.packs) { pack in
                        SceneCard(pack: pack, recorded: viewModel.recordedCount(for: pack)) {
                            GameSFX.play(.select)
                            viewModel.open(pack)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background { GameBackdrop() }
        .overlay {
            if library.isImporting {
                ProcessingIndicator(message: library.importMessage, progress: library.importProgress)
            }
        }
        .hidesNavigationBar()
        .dubContentGate(isPresented: $viewModel.showContentGate) { viewModel.contentGateDidConfirm() }
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.folder, .zip, .sevenZipArchive, .rarArchive, .archive],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImport(result)
        }
        .navigationDestination(item: $viewModel.selectedPack) { pack in
            GameDubRoundView(pack: pack)
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
        // A pack handed in from Files or AirDrop. Cleared after the import, not before: the
        // URL is this task's id. See `DubLibraryView`.
        .task(id: pendingImportURL) {
            guard let url = pendingImportURL else { return }
            await viewModel.importPack(from: url)
            pendingImportURL = nil
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: library.isImporting)
    }

    private var header: some View {
        ZStack {
            OutlinedText(text: GameStrings.pickScene, size: 30, color: .white)
            HStack {
                GameRoundButton(symbol: "chevron.backward", label: Strings.Main.back, diameter: 50) { dismiss() }
                Spacer()
                GameRoundButton(symbol: "plus", label: Strings.Dub.importPack, diameter: 50) {
                    viewModel.requestImport()
                }
                .disabled(library.isImporting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

/// One scene: its still on a screen inside an ivory card, its title, and a counter of the
/// lines dubbed so far that fills like a progress bar.
private struct SceneCard: View {
    let pack: DubPack
    let recorded: Int
    let action: () -> Void

    private var total: Int { max(pack.lines.count, 1) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                DubStillImage(url: pack.iconURL)
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    // On the show's monitor.
                    .gameCRT(0.7)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.gameNavy, lineWidth: 3)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if recorded >= pack.lines.count, !pack.lines.isEmpty {
                            GameStar(isLit: true, size: 48)
                                .padding(8)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.white)
                                .shadow(color: .gameNavy, radius: 0, x: 0, y: 2)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.gameCoral))
                                .overlay(Circle().strokeBorder(Color.gameNavy, lineWidth: 3))
                                .gameShine(0.5)
                                .padding(10)
                                .accessibilityHidden(true)
                        }
                    }

                HStack(alignment: .center, spacing: 10) {
                    Text(pack.title)
                        .font(.gameDisplay(22))
                        .foregroundStyle(Color.gameNavy)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Text(pack.formattedDuration)
                        .font(.game(14, weight: .bold))
                        .foregroundStyle(Color.gameNavy.opacity(0.6))
                        .monospacedDigit()
                }

                // Lines dubbed: a pip per line, lit as each is done, like a level's checkpoints.
                HStack(spacing: 4) {
                    ForEach(0..<pack.lines.count, id: \.self) { index in
                        Capsule()
                            .fill(index < recorded ? Color.gameCyan : Color.gameNavy.opacity(0.12))
                            .overlay(Capsule().strokeBorder(Color.gameNavy, lineWidth: 2))
                            .frame(height: 14)
                    }
                    Text("\(recorded)/\(pack.lines.count)")
                        .font(.gameDisplay(15))
                        .foregroundStyle(Color.gameNavy)
                        .monospacedDigit()
                        .fixedSize()
                        .padding(.leading, 4)
                }
            }
            .padding(14)
            .gameCard()
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel(pack.title)
        .accessibilityValue("\(recorded) / \(pack.lines.count)")
    }
}
