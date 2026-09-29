//
//  HelpView.swift
//  ReverseSinging
//
//  How everything works, searchable, and a way to reach a person
//

import SwiftUI

/// Help, opened on the chapter about the screen it came from.
///
/// It starts with the one idea new players most often miss, how a backwards copy turns back
/// into the song, drawn rather than described. Then every question by chapter, the one they
/// came from first, then a way to write to the person who made the app.
struct HelpView: View {
    @StateObject private var viewModel: HelpViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @FocusState private var isSearchFocused: Bool

    init(topic: HelpTopic = .gettingStarted) {
        _viewModel = StateObject(wrappedValue: HelpViewModel(topic: topic))
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorHeaderBar {
                Text(Strings.Help.title)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)

                Spacer()

                EditorToolbarButton(icon: "xmark", label: Strings.Help.close) {
                    dismiss()
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        searchField

                        if viewModel.isSearching {
                            searchResults
                        } else {
                            // Only inside Reverse Singing: from the menu, Help is about the whole
                            // app, and one game's picture at the top read as the answer to it.
                            if viewModel.initialTopic == .reverse {
                                HelpReverseFlowCard()
                            }

                            topicStrip(proxy: proxy)

                            ForEach(viewModel.topics) { topic in
                                section(topic)
                                    .id(topic)
                            }
                        }

                        contactCard
                        legalLinks
                    }
                    .padding(.horizontal, EditorMetrics.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Color.rsSurface0.ignoresSafeArea())
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.rsTextTertiary)
                .accessibilityHidden(true)

            TextField(Strings.Help.searchPrompt, text: $viewModel.query)
                .font(.rsBodyMedium)
                .foregroundColor(.rsTextPrimary)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.rsTextTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.Help.clearSearch)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = viewModel.searchResults
        if results.isEmpty {
            Text(Strings.Help.searchEmpty)
                .font(.rsBodyMedium)
                .foregroundColor(.rsTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        } else {
            articleList(results)
        }
    }

    // MARK: - Chapters

    /// The chapters as a strip of chips, each one a jump down the page.
    private func topicStrip(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HelpTopic.allCases) { topic in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.rsQuick) { proxy.scrollTo(topic, anchor: .top) }
                    } label: {
                        Label(topic.title, systemImage: topic.symbol)
                            .font(.rsCaption)
                            .foregroundColor(.rsTextSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .editorPanel(.rsSurface1, radius: 16)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(.horizontal, -EditorMetrics.gutter)
        .contentMargins(.horizontal, EditorMetrics.gutter, for: .scrollContent)
    }

    private func section(_ topic: HelpTopic) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: topic.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.rsHighlight)
                    .accessibilityHidden(true)
                EditorSectionHeader(title: topic.title)
            }
            .accessibilityAddTraits(.isHeader)

            articleList(topic.articles)
        }
    }

    private func articleList(_ articles: [HelpArticle]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                if index > 0 { EditorRule() }
                HelpArticleRow(
                    article: article,
                    isExpanded: viewModel.isExpanded(article)
                ) {
                    withAnimation(.rsQuick) { viewModel.toggle(article) }
                }
            }
        }
        .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
    }

    // MARK: - A person

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.rsHighlight)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Strings.Help.contactTitle)
                        .font(.rsButtonMedium)
                        .foregroundColor(.rsTextPrimary)
                    Text(Strings.Help.contactMessage)
                        .font(.rsBodySmall)
                        .foregroundColor(.rsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let url = viewModel.contactURL {
                Button {
                    viewModel.contactTapped()
                    openURL(url)
                } label: {
                    Text(Strings.Help.contactButton)
                        .font(.rsButtonMedium)
                        .foregroundColor(.rsSurface0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                                .fill(Color.rsTextPrimary)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
    }

    private var legalLinks: some View {
        HStack(spacing: 20) {
            Button(Strings.Settings.privacyPolicy) { openURL(AppLinks.privacyPolicy) }
            Button(Strings.Pro.Fallback.terms) { openURL(AppLinks.termsOfUse) }
        }
        .font(.rsCaption)
        .foregroundColor(.rsTextTertiary)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HelpView(topic: .reverse)
}
