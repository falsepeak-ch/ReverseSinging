//
//  GameSoundPickerView.swift
//  DubloonGame
//
//  Sound Imitation's level select: a category at a time, a card per sound, stars for the best.
//

import SwiftUI
import DubScoring

struct GameSoundPickerView: View {
    @StateObject private var viewModel = SoundLibraryViewModel()
    @State private var category: ImitationCategory = .animals
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            header

            categoryTabs
                .padding(.vertical, 10)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(Array(viewModel.sounds(in: category).enumerated()), id: \.element.id) { index, sound in
                        SoundCard(sound: sound, grade: viewModel.grade(for: sound), order: index) {
                            GameSFX.play(.select)
                            viewModel.open(sound)
                        }
                    }
                }
                // A new category deals its cards in again.
                .id(category)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background { GameBackdrop() }
        .hidesNavigationBar()
        .navigationDestination(item: $viewModel.selectedSound) { sound in
            GameImitationRoundView(sound: sound, onNext: next(after: sound).map { next in
                { viewModel.selectedSound = next }
            })
            .id(sound.id)
        }
        .onAppear { viewModel.onAppear() }
    }

    private var header: some View {
        ZStack {
            OutlinedText(text: GameStrings.pickSound, size: 30, color: .white)
                .padding(.horizontal, 64)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack {
                GameRoundButton(symbol: "chevron.backward", label: Strings.Main.back, diameter: 50) { dismiss() }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(viewModel.categories) { item in
                    Button {
                        HapticManager.shared.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { category = item }
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.title)
                            let won = stars(in: item)
                            if won > 0 {
                                HStack(spacing: 2) {
                                    GameStar(isLit: true, size: 18, shines: false)
                                    Text("\(won)").monospacedDigit()
                                }
                                .font(.gameDisplay(16))
                            }
                        }
                    }
                    .buttonStyle(GamePillButtonStyle(
                        fill: item == category ? .gameCyan : .gameIvory,
                        height: 46,
                        text: item == category ? .white : .gameNavy
                    ))
                    .accessibilityAddTraits(item == category ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    /// Stars won in a category, for its tab.
    private func stars(in category: ImitationCategory) -> Int {
        viewModel.sounds(in: category).reduce(0) { total, sound in
            total + (viewModel.grade(for: sound).map(ScorePart.stars(for:)) ?? 0)
        }
    }

    /// The sound after this one, across categories, for the round's Next button.
    private func next(after sound: ImitationSound) -> ImitationSound? {
        let all = ImitationSoundLibrary.all
        guard let index = all.firstIndex(of: sound), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}

/// One sound, as a level card: its artwork on a lit plinth, its name, and up to three stars
/// for the best go. A sound with three stars wears a gold rim. Cards deal in one after
/// another when the grid appears.
private struct SoundCard: View {
    let sound: ImitationSound
    let grade: DubGrade?
    let order: Int
    let action: () -> Void

    @State private var isDealt = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stars: Int { grade.map(ScorePart.stars(for:)) ?? 0 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                GameSoundArt(sound: sound, size: 96)
                    .padding(.top, 14)
                    .background(alignment: .bottom) {
                        // The plinth's pool of light.
                        Ellipse()
                            .fill(RadialGradient(
                                colors: [(stars == 3 ? Color.gameGold : .gameCyan).opacity(0.45), .clear],
                                center: .center, startRadius: 2, endRadius: 60
                            ))
                            .frame(width: 120, height: 34)
                            .offset(y: 10)
                    }

                Text(sound.name)
                    .font(.gameDisplay(19))
                    .foregroundStyle(Color.gameNavy)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 44)

                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        GameStar(isLit: index < stars, size: index == 1 ? 30 : 26, shines: false)
                            .offset(y: index == 1 ? -3 : 0)
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .gameCard(fill: stars == 3 ? Color(gameHex: 0xFFF4D6) : .gameIvory)
            .overlay {
                if stars == 3 {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.gameGold, lineWidth: 3)
                        .padding(4)
                        .gameShine(0.6)
                }
            }
        }
        .buttonStyle(CardPressStyle())
        .scaleEffect(isDealt ? 1 : 0.6)
        .rotationEffect(.degrees(isDealt ? 0 : (order.isMultiple(of: 2) ? -8 : 8)))
        .opacity(isDealt ? 1 : 0)
        .onAppear {
            guard !isDealt else { return }
            guard !reduceMotion else { isDealt = true; return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62).delay(Double(min(order, 8)) * 0.05)) {
                isDealt = true
            }
        }
        .accessibilityLabel(sound.name)
        .accessibilityValue(grade.map { _ in "\(stars) / 3" } ?? Strings.Imitate.untried)
    }
}

/// Cards sink a little under the finger.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// The set, dimmed under a navy wash, for the screens between rounds.
struct GameBackdrop: View {
    var body: some View {
        Image(GameArt.stage)
            .resizable()
            .scaledToFill()
            .overlay(Color.gameNavy.opacity(0.55))
            .ignoresSafeArea()
    }
}
