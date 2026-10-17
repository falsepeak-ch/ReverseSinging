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
                    ForEach(viewModel.sounds(in: category)) { sound in
                        SoundCard(sound: sound, grade: viewModel.grade(for: sound)) {
                            SoundManager.shared.play(.mechanicalClick)
                            viewModel.open(sound)
                        }
                    }
                }
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
                        Text(item.title)
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

    /// The sound after this one, across categories, for the round's Next button.
    private func next(after sound: ImitationSound) -> ImitationSound? {
        let all = ImitationSoundLibrary.all
        guard let index = all.firstIndex(of: sound), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}

/// One sound: its artwork on an ivory card, its name, and up to three stars for the best go.
private struct SoundCard: View {
    let sound: ImitationSound
    let grade: DubGrade?
    let action: () -> Void

    private var stars: Int {
        switch grade {
        case .perfect?, .great?: return 3
        case .good?: return 2
        case .close?: return 1
        default: return 0
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ImitationSoundArtwork(sound: sound, size: 92)
                    .padding(.top, 14)

                Text(sound.name)
                    .font(.game(17))
                    .foregroundStyle(Color.gameNavy)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 44)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(index < stars ? Color.gameGold : Color.gameNavy.opacity(0.18))
                    }
                }
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .gameCard()
        }
        .buttonStyle(CardPressStyle())
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
