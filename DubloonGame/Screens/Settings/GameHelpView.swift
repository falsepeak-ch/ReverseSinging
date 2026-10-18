//
//  GameHelpView.swift
//  DubloonGame
//
//  Help, drawn as the game: the set behind, a search pill, chapters as ivory cards.
//

import SwiftUI

/// The game's Help. Same questions and the same view model as Dubloon's (`HelpViewModel`),
/// laid out like the game's settings: a navy header band, a search field, the chapters as
/// chips, each chapter an ivory card under a navy plaque, and the contact card last.
///
/// Where the game words an answer differently (it has two games, not four), the text comes
/// from the game's own table; see `HelpArticle.question` and `answer`.
struct GameHelpContent: View {
    @ObservedObject var viewModel: HelpViewModel
    let onClose: () -> Void
    let openURL: (URL) -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    searchField

                    if viewModel.isSearching {
                        let results = viewModel.searchResults
                        if results.isEmpty {
                            Text(Strings.Help.searchEmpty)
                                .font(.game(17, weight: .semibold))
                                .foregroundStyle(Color.gameIvory)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            card(title: nil, articles: results)
                        }
                    } else {
                        chips(proxy: proxy)
                        ForEach(viewModel.topics) { topic in
                            card(title: topic.title, articles: topic.articles)
                                .id(topic)
                        }
                    }

                    contactCard
                    legalLinks
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top) { header }
        }
        .background { GameBackdrop() }
        .environment(\.colorScheme, .light)
        .onAppear { viewModel.onAppear() }
    }

    private var header: some View {
        ZStack {
            OutlinedText(text: Strings.Help.title, size: 30, color: .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 64)
            HStack {
                Spacer()
                GameRoundButton(symbol: "xmark", label: Strings.Help.close, diameter: 48, action: onClose)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            LinearGradient(
                stops: [.init(color: .gameNavy, location: 0), .init(color: .gameNavy, location: 0.7), .init(color: .gameNavy.opacity(0), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.gameNavy)
                .accessibilityHidden(true)
            TextField(Strings.Help.searchPrompt, text: $viewModel.query)
                .font(.game(17, weight: .semibold))
                .foregroundStyle(Color.gameNavy)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !viewModel.query.isEmpty {
                Button { viewModel.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.gameNavy.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.Help.clearSearch)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Capsule().fill(Color.gameIvory))
        .overlay(Capsule().strokeBorder(Color.gameNavy, lineWidth: 3))
        .background(Capsule().fill(Color.gameNavy).offset(y: 4))
    }

    private func chips(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(HelpTopic.available) { topic in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { proxy.scrollTo(topic, anchor: .top) }
                    } label: {
                        Text(topic.title)
                    }
                    .buttonStyle(GamePillButtonStyle(fill: .gameIvory, height: 44))
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    /// A chapter, or the search results, as an ivory card of questions.
    private func card(title: String?, articles: [HelpArticle]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                if index > 0 {
                    Rectangle().fill(Color.gameNavy.opacity(0.1)).frame(height: 2).padding(.horizontal, 16)
                }
                GameHelpRow(article: article, isExpanded: viewModel.isExpanded(article)) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { viewModel.toggle(article) }
                }
            }
        }
        .padding(.top, title == nil ? 4 : 16)
        .padding(.bottom, 4)
        .gameCard(radius: 24, lip: 5)
        .overlay(alignment: .topLeading) {
            if let title {
                Text(title.uppercased())
                    .font(.gameDisplay(15))
                    .tracking(0.8)
                    .foregroundStyle(Color.gameCyan)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.gameNavy))
                    .offset(x: 18, y: -15)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.Help.contactTitle)
                .font(.gameDisplay(21))
                .foregroundStyle(Color.gameNavy)
            Text(Strings.Help.contactMessage)
                .font(.game(15, weight: .medium))
                .foregroundStyle(Color.gameNavy.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            if let url = viewModel.contactURL {
                Button {
                    viewModel.contactTapped()
                    openURL(url)
                } label: {
                    Label(Strings.Help.contactButton, systemImage: "envelope.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(GamePillButtonStyle(height: 54))
            }
        }
        .padding(18)
        .gameCard(radius: 24, lip: 5)
    }

    private var legalLinks: some View {
        HStack(spacing: 24) {
            Button(Strings.Settings.privacyPolicy) { openURL(AppLinks.privacyPolicy) }
            Button(Strings.Pro.Fallback.terms) { openURL(AppLinks.termsOfUse) }
        }
        .font(.game(14, weight: .bold))
        .foregroundStyle(Color.gameIvory.opacity(0.75))
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// One question, opening onto its answer.
private struct GameHelpRow: View {
    let article: HelpArticle
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    Text(article.question)
                        .font(.gameDisplay(18))
                        .foregroundStyle(Color.gameNavy)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color.gameNavy)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(isExpanded ? Color.gameCyan : Color.gameNavy.opacity(0.08)))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? Strings.Help.expanded : Strings.Help.collapsed)

            if isExpanded {
                Text(article.answer)
                    .font(.game(15, weight: .medium))
                    .foregroundStyle(Color.gameNavy.opacity(0.75))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }
}
