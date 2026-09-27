//
//  SoundLibraryView.swift
//  ReverseSinging
//
//  The sounds on offer, grouped, each with its best score so far
//

import SwiftUI

struct SoundLibraryView: View {

    @StateObject private var viewModel = SoundLibraryViewModel()
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 10)]

    var body: some View {
        ZStack {
            Color.rsSurface0
                .ignoresSafeArea()
                .filmGrain()

            VStack(spacing: 0) {
                EditorScreenHeader(title: GameMode.imitate.title, onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(Strings.Imitate.libraryHint)
                            .font(.rsBodySmall)
                            .foregroundColor(.rsTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(viewModel.categories) { category in
                            section(category)
                        }
                    }
                    .padding(.horizontal, EditorMetrics.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .hidesNavigationBar()
        .navigationDestination(item: $viewModel.selectedSound) { sound in
            ImitationChallengeView(sound: sound)
        }
        .onAppear { viewModel.onAppear() }
    }

    private func section(_ category: ImitationCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorSectionHeader(title: category.title)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.sounds(in: category)) { sound in
                    SoundTile(
                        sound: sound,
                        best: viewModel.best(for: sound),
                        grade: viewModel.grade(for: sound)
                    ) {
                        viewModel.open(sound)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SoundLibraryView()
    }
    .preferredColorScheme(.dark)
}
