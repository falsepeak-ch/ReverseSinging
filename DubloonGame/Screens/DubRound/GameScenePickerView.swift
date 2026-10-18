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
/// for its picture, with turning rays and a spotlight behind the clapperboard, and in place of
/// the title and progress a big cyan "add" key, so it reads as a button before anything else.
/// A light runs round its dashed rim. It opens the import gate, which asks whether the movie is
/// already on the phone and walks through finding one if not.
///
/// Everything moves with repeating transform and opacity animations, which the render server
/// interpolates, rather than a per-frame timeline that rebuilds the card sixty times a second.
private struct AddSceneCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { EmptyView() }
            .buttonStyle(AddSceneCardStyle())
            .accessibilityLabel(Strings.Dub.importPack)
            .accessibilityAddTraits(.isButton)
    }
}

private struct AddSceneCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AddSceneCardFace(isPressed: configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

private struct AddSceneCardFace: View {
    let isPressed: Bool

    @State private var isLive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let radius: CGFloat = 22

    var body: some View {
        VStack(spacing: 10) {
            monitor
            addKey
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.gameNavy.opacity(0.8))
        )
        // Where a scene card's lip would be, so the row spacing matches.
        .padding(.bottom, 5)
        .overlay { rim }
        .onAppear {
            guard !reduceMotion else { return }
            isLive = true
        }
    }

    // MARK: - Monitor

    private var monitor: some View {
        Color.gameNavy
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { rays }
            .overlay {
                RadialGradient(
                    colors: [Color.gameCyan.opacity(0.5), Color.gameCyan.opacity(0)],
                    center: UnitPoint(x: 0.5, y: 0.55),
                    startRadius: 0,
                    endRadius: 170
                )
                .opacity(isLive ? 1 : 0.75)
                .animation(isLive ? .easeInOut(duration: 1.6).repeatForever() : nil, value: isLive)
            }
            .overlay { sparkles }
            .overlay { clapper }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.gameCyan.opacity(0.5), lineWidth: 3)
            )
            .accessibilityHidden(true)
    }

    /// Wedges of light behind the art, turning slowly like a game-show backdrop.
    private var rays: some View {
        let count = 14
        let stops: [Gradient.Stop] = (0..<count).flatMap { index -> [Gradient.Stop] in
            let start = Double(index) / Double(count)
            let half = 0.5 / Double(count)
            return [
                .init(color: Color.gameCyan.opacity(0.18), location: start),
                .init(color: Color.gameCyan.opacity(0.18), location: start + half),
                .init(color: .clear, location: start + half),
                .init(color: .clear, location: start + 2 * half),
            ]
        }
        return AngularGradient(stops: stops, center: .center)
            .frame(width: 520, height: 520)
            .rotationEffect(.degrees(isLive ? 360 : 0))
            .animation(isLive ? .linear(duration: 40).repeatForever(autoreverses: false) : nil, value: isLive)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: 8)
            .mask(
                RadialGradient(colors: [.white, .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.55),
                               startRadius: 30, endRadius: 200)
            )
    }

    /// The clapperboard, bobbing, with a gold plus on its corner that beats.
    private var clapper: some View {
        Image("game-movies")
            .resizable()
            .scaledToFit()
            .frame(width: 132, height: 132)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.gameNavy)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.gameGold))
                    .overlay(Circle().strokeBorder(Color.gameNavy, lineWidth: 3.5))
                    .overlay(alignment: .top) {
                        Capsule().fill(Color.white.opacity(0.5)).frame(width: 14, height: 4).padding(.top, 6)
                    }
                    .background(Circle().fill(Color.gameNavy).offset(y: 4))
                    .scaleEffect(isLive ? 1.12 : 1)
                    .animation(isLive ? .easeInOut(duration: 0.45).repeatForever() : nil, value: isLive)
                    .offset(x: 22, y: 10)
            }
            .rotationEffect(.degrees(isLive ? 3 : -3))
            .offset(y: isLive ? -5 : 5)
            .animation(isLive ? .easeInOut(duration: 1.5).repeatForever() : nil, value: isLive)
            .offset(y: 4)
    }

    /// Four-point glints winking on and off around the art, each on its own beat.
    private var sparkles: some View {
        let spots: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
            (0.20, 0.26, 26, 0), (0.80, 0.22, 20, 0.6), (0.86, 0.72, 24, 1.1),
            (0.14, 0.74, 18, 1.6), (0.64, 0.12, 14, 0.9),
        ]
        return GeometryReader { proxy in
            ForEach(spots.indices, id: \.self) { index in
                let spot = spots[index]
                Image(systemName: "sparkle")
                    .font(.system(size: spot.size, weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.gameGold : Color.gameIvory)
                    .scaleEffect(isLive ? 1 : 0.35)
                    .rotationEffect(.degrees(isLive ? 45 : 0))
                    .opacity(isLive ? 1 : (reduceMotion ? 0.7 : 0))
                    .animation(
                        isLive ? .easeInOut(duration: 0.9).repeatForever().delay(spot.delay) : nil,
                        value: isLive
                    )
                    .position(x: proxy.size.width * spot.x, y: proxy.size.height * spot.y)
            }
        }
    }

    // MARK: - Add key

    /// The card's own key: a cyan pill with the plus and the words, pushed in with the card, and
    /// a ring that keeps rippling out of it.
    private var addKey: some View {
        let lip: CGFloat = 5
        return HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .heavy))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.gameCyan, Color.gameNavy)
            Text(Strings.Dub.importPack)
                .font(.gameDisplay(21))
                .foregroundStyle(Color.gameNavy)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background {
            ZStack {
                Capsule().fill(Color.gameNavy).offset(y: isPressed ? 1 : lip)
                Capsule().fill(Color.gameCyan)
                    .offset(y: isPressed ? lip - 1 : 0)
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.45))
                            .frame(height: 4)
                            .padding(.horizontal, 22)
                            .padding(.top, 6)
                            .offset(y: isPressed ? lip - 1 : 0)
                    }
                Capsule().strokeBorder(Color.gameNavy, lineWidth: 3.5)
                    .offset(y: isPressed ? lip - 1 : 0)
            }
        }
        .offset(y: isPressed ? lip - 1 : 0)
        .background {
            // The ripple: a ring leaving the key, over and over.
            Capsule()
                .strokeBorder(Color.gameCyan, lineWidth: 3)
                .scaleEffect(x: isLive ? 1.06 : 1, y: isLive ? 1.5 : 1)
                .opacity(isLive ? 0 : 0.9)
                .animation(isLive ? .easeOut(duration: 1.4).repeatForever(autoreverses: false) : nil, value: isLive)
        }
        .padding(.bottom, lip)
    }

    // MARK: - Rim

    /// A dashed cyan edge with a bright light running round it.
    private var rim: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            shape.strokeBorder(Color.gameCyan.opacity(0.55), style: StrokeStyle(lineWidth: 3.5, dash: [14, 10]))
            GeometryReader { proxy in
                let side = hypot(proxy.size.width, proxy.size.height)
                let comet = AngularGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.78),
                        .init(color: Color.gameCyan, location: 0.92),
                        .init(color: .white, location: 0.985),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center
                )
                .frame(width: side, height: side)
                .rotationEffect(.degrees(isLive ? 360 : 0))
                .animation(isLive ? .linear(duration: 3.2).repeatForever(autoreverses: false) : nil, value: isLive)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                ZStack {
                    // A soft wide band for the glow, then the bright line itself.
                    comet.opacity(0.4).mask(shape.strokeBorder(lineWidth: 9))
                    comet.mask(shape.strokeBorder(lineWidth: 4))
                }
                .opacity(isLive ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
    }
}
