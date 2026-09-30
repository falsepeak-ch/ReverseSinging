//
//  MacHelpView.swift
//  DubloonMac
//
//  Help ▸ Dubloon Help: the chapters down a sidebar, their questions beside it, and a way to
//  write to a person
//

import SwiftUI

struct MacHelpView: View {
    @ObservedObject private var viewModel = MacHelpViewModel.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.allCases, selection: $viewModel.topic) { topic in
                Label(topic.title, systemImage: topic.symbol)
                    .tag(topic)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 280)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(viewModel.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.rsTextPrimary)

                    if !viewModel.help.isSearching, viewModel.topic == .reverse {
                        HelpReverseFlowCard()
                    }

                    if viewModel.articles.isEmpty {
                        Text(Strings.Help.searchEmpty)
                            .font(.rsBodySmall)
                            .foregroundColor(.rsTextTertiary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.articles) { article in
                                articleRow(article)
                                if article != viewModel.articles.last { Divider() }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.rsSurface1))
                    }

                    contactCard
                        .padding(.top, 10)

                    HStack(spacing: 18) {
                        Button(Strings.Settings.privacyPolicy) { openURL(AppLinks.privacyPolicy) }
                        Button(Strings.Pro.Fallback.terms) { openURL(AppLinks.termsOfUse) }
                    }
                    .buttonStyle(.link)
                    .font(.rsCaption)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .background(Color.rsSurface0)
        }
        .searchable(text: Binding(get: { viewModel.help.query }, set: { viewModel.help.query = $0 }), placement: .sidebar, prompt: Strings.Help.searchPrompt)
        .frame(minWidth: 760, minHeight: 520)
        .preferredColorScheme(.dark)
    }

    private func articleRow(_ article: HelpArticle) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { viewModel.help.isExpanded(article) },
            set: { _ in viewModel.help.toggle(article) }
        )) {
            Text(article.answer)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                if viewModel.help.isSearching {
                    Text(article.topic.title)
                        .editorLabelStyle(.rsTextTertiary)
                }
                Text(article.question)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.help.toggle(article) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var contactCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "envelope.open")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.rsHighlight)

            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.Help.contactTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
                Text(Strings.Help.contactMessage)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let url = viewModel.help.contactURL {
                Button(Strings.Help.contactButton) {
                    viewModel.help.contactTapped()
                    openURL(url)
                }
                .platformProminentButton()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.rsSurface1))
    }
}

// MARK: - Button

/// The ? in a workspace's toolbar: Help, open on that workspace's chapter.
struct MacHelpButton: View {
    let topic: HelpTopic
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            MacHelpViewModel.shared.open(topic, with: openWindow)
        } label: {
            Label(Strings.Help.title, systemImage: "questionmark.circle")
        }
        .help(Strings.Help.title)
    }
}
