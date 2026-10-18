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
                    // First, where the next scene would go: the way to bring your own in.
                    AddSceneCard {
                        GameSFX.play(.select)
                        viewModel.requestImport()
                    }
                    .disabled(library.isImporting)

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
        #if DEBUG
        .task {
            // The screenshot run's dub round: the first scene, opened once its packs are in.
            guard GameShot.current == .dub, viewModel.selectedPack == nil else { return }
            for _ in 0..<40 where library.packs.isEmpty { try? await Task.sleep(for: .milliseconds(100)) }
            if let pack = library.packs.first { viewModel.selectedPack = pack }
        }
        #endif
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

/// The empty slot at the head of the scenes, the same size as a scene card: a monitor waiting
/// for its picture, with a spotlight and turning rays behind the clapperboard, a gold plus that
/// beats like a call to come on stage, sparkles, and a cyan rim of marching lights. It opens the
/// import gate, which asks whether the movie is already on the phone and helps find one if not.
private struct AddSceneCard: View {
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let radius: CGFloat = 22

    var body: some View {
        Button(action: action) {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                content(t)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.gameNavy.opacity(0.78))
                    )
                    // Where a scene card's lip would be, so the row spacing matches.
                    .padding(.bottom, 5)
                    .overlay { rim(t) }
            }
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel(Strings.Dub.importPack)
    }

    private func content(_ t: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            monitor(t)

            // The same rows as a scene card, so the two are exactly the same height.
            HStack(alignment: .center, spacing: 10) {
                Text(Strings.Dub.importPack)
                    .font(.gameDisplay(22))
                    .foregroundStyle(Color.gameIvory)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("0:00")
                    .font(.game(14, weight: .bold))
                    .hidden()
            }
            // Empty checkpoints, waiting for the lines of whatever comes in.
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { index in
                    let lit = (sin(t * 2.4 - Double(index) * 0.7) + 1) / 2
                    Capsule()
                        .fill(Color.gameCyan.opacity(0.08 + lit * 0.22))
                        .overlay(Capsule().strokeBorder(Color.gameCyan.opacity(0.35 + lit * 0.4), lineWidth: 2))
                        .frame(height: 14)
                }
                Text("0/0")
                    .font(.gameDisplay(15))
                    .fixedSize()
                    .padding(.leading, 4)
                    .hidden()
            }
        }
    }

    /// The screen where the still would be: dark, lit from above, with the art centre stage.
    private func monitor(_ t: TimeInterval) -> some View {
        Color.gameNavy
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { rays(t) }
            .overlay {
                // The spotlight, breathing.
                RadialGradient(
                    colors: [Color.gameCyan.opacity(0.42 + 0.08 * sin(t * 1.6)), Color.gameCyan.opacity(0)],
                    center: UnitPoint(x: 0.5, y: 0.52),
                    startRadius: 0,
                    endRadius: 170
                )
                .blendMode(.screen)
            }
            .overlay { sparkles(t) }
            .overlay { clapper(t) }
            .gameCRT(0.55)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.gameCyan.opacity(0.55), lineWidth: 3)
            )
    }

    /// Slow-turning wedges of light behind the art, like a game-show backdrop.
    private func rays(_ t: TimeInterval) -> some View {
        let count = 14
        let stops: [Gradient.Stop] = (0..<count).flatMap { index -> [Gradient.Stop] in
            let start = Double(index) / Double(count)
            let half = 0.5 / Double(count)
            return [
                .init(color: Color.gameCyan.opacity(0.16), location: start),
                .init(color: Color.gameCyan.opacity(0.16), location: start + half),
                .init(color: .clear, location: start + half),
                .init(color: .clear, location: start + 2 * half),
            ]
        }
        return AngularGradient(stops: stops, center: UnitPoint(x: 0.5, y: 0.52))
            .rotationEffect(.degrees(t * 6))
            .scaleEffect(2.2)
            .mask(
                RadialGradient(colors: [.white, .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.52),
                               startRadius: 30, endRadius: 190)
            )
    }

    /// The clapperboard, bobbing, with the beating gold plus on its corner.
    private func clapper(_ t: TimeInterval) -> some View {
        let beat = pow(max(0, sin(t * 3.2)), 6)
        return Image("game-movies")
            .resizable()
            .scaledToFit()
            .frame(width: 138, height: 138)
            .rotationEffect(.degrees(sin(t * 1.3) * 3))
            .offset(y: sin(t * 1.9) * 5)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color.gameNavy)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.gameGold))
                    .overlay(Circle().strokeBorder(Color.gameNavy, lineWidth: 3.5))
                    .gameShine(0.6)
                    .background(Circle().fill(Color.gameNavy).offset(y: 4))
                    .shadow(color: Color.gameGold.opacity(0.35 + beat * 0.5), radius: 8 + beat * 10)
                    .scaleEffect(1 + beat * 0.14)
                    .offset(x: 26, y: 12)
            }
            .accessibilityHidden(true)
    }

    /// Four-point glints that wink on and off around the art.
    private func sparkles(_ t: TimeInterval) -> some View {
        let spots: [(x: CGFloat, y: CGFloat, size: CGFloat, phase: Double)] = [
            (0.20, 0.26, 26, 0), (0.80, 0.22, 20, 1.7), (0.86, 0.70, 24, 3.1),
            (0.14, 0.74, 18, 4.4), (0.64, 0.12, 14, 2.4),
        ]
        return GeometryReader { proxy in
            ForEach(spots.indices, id: \.self) { index in
                let spot = spots[index]
                let glow = pow(max(0, sin(t * 1.4 + spot.phase)), 3)
                Image(systemName: "sparkle")
                    .font(.system(size: spot.size, weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.gameGold : Color.gameIvory)
                    .scaleEffect(0.4 + glow * 0.8)
                    .rotationEffect(.degrees(glow * 45))
                    .opacity(reduceMotion ? 0.7 : glow)
                    .position(x: proxy.size.width * spot.x, y: proxy.size.height * spot.y)
            }
        }
        .accessibilityHidden(true)
    }

    /// Marching lights round the card's edge, with a soft cyan glow under them.
    private func rim(_ t: TimeInterval) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            shape.strokeBorder(Color.gameCyan.opacity(0.25), lineWidth: 3.5)
            shape.strokeBorder(
                Color.gameCyan,
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [16, 11], dashPhase: -t * 28)
            )
            .shadow(color: Color.gameCyan.opacity(0.8), radius: 6)
        }
    }
}
