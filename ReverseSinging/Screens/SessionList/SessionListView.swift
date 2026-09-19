//
//  SessionListView.swift
//  ReverseSinging
//
//  List of saved recording sessions
//

import SwiftUI

struct SessionListView: View {
    @StateObject private var viewModel: SessionListViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme

    init(game: ReverseGameViewModel) {
        _viewModel = StateObject(wrappedValue: SessionListViewModel(game: game))
    }

    // Computed effective color scheme based on theme mode
    private var effectiveColorScheme: ColorScheme {
        viewModel.effectiveColorScheme(system: systemColorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rsBackgroundAdaptive(for: effectiveColorScheme).ignoresSafeArea()

                if viewModel.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .id(viewModel.game.appState.themeMode)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.onAppear() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.rsTextAdaptive(for: effectiveColorScheme))
                    }
                }
            }
        }
        .preferredColorScheme(viewModel.preferredColorScheme)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image("archive")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .scaleIn(delay: 0.1)

            Text(Strings.SessionList.Empty.title)
                .font(.rsDisplay(32))
                .foregroundColor(Color.rsTextAdaptive(for: effectiveColorScheme))
                .fadeIn(delay: 0.2)

            Text(Strings.SessionList.Empty.message)
                .font(.rsBodyMedium)
                .foregroundColor(Color.rsSecondaryTextAdaptive(for: effectiveColorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fadeIn(delay: 0.3)
            Spacer()
        }
    }

    // MARK: - Session List

    private var sessionListView: some View {
        List {
            ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                SessionRow(session: session, viewModel: viewModel.game)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .slideIn(delay: Double(index) * 0.1)
            }
            .onDelete { offsets in
                viewModel.deleteSessions(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.rsBackgroundAdaptive(for: effectiveColorScheme))
    }
}

// MARK: - Preview

#Preview {
    SessionListView(game: ReverseGameViewModel())
}
