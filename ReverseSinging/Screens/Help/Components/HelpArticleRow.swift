//
//  HelpArticleRow.swift
//  ReverseSinging
//
//  One question in Help, opening onto its answer
//

import SwiftUI

struct HelpArticleRow: View {
    let article: HelpArticle
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(article.question)
                        .font(.rsButtonMedium)
                        .foregroundColor(.rsTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.rsTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? Strings.Help.expanded : Strings.Help.collapsed)
            .accessibilityHint(isExpanded ? "" : Strings.Help.expandHint)

            if isExpanded {
                Text(article.answer)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextSecondary)
                    .lineSpacing(4)
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
