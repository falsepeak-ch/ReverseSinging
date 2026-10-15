//
//  DubPackCard.swift
//  ReverseSinging
//
//  One installed pack in the library, like a clip in a bin
//

import SwiftUI

struct DubPackCard: View {
    let pack: DubPack
    let recordedCount: Int
    /// Tapping anywhere on the card opens the pack.
    let onOpen: () -> Void
    /// Larger card for a regular-width, regular-height window (iPhone Duo open),
    /// so a handful of packs uses the screen instead of a strip along its top.
    var prominent = false

    private var cardHeight: CGFloat { prominent ? 150 : 74 }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 0) {
                thumbnail
                info
            }
        }
        .buttonStyle(.plain)
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
        .editorPanel()
    }

    /// 16:9 thumbnail, like a clip in a bin.
    private var thumbnail: some View {
        DubStillImage(url: pack.iconURL)
            .frame(width: cardHeight * 16 / 9, height: cardHeight)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.rsStroke)
                    .frame(width: EditorMetrics.hairline)
            }
            .contentShape(Rectangle())
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(pack.title)
                .font(.rsButtonSmall)
                .foregroundColor(.rsTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                Text(pack.formattedDuration)
                    .font(.rsTimecodeSmall)
                    .foregroundColor(.rsTextSecondary)

                Text("·")
                    .foregroundColor(.rsTextTertiary)

                Text(pack.authorsDescription)
                    .font(.rsMeta)
                    .foregroundColor(.rsTextTertiary)
                    .lineLimit(1)
            }

            DubProgressBar(recorded: recordedCount, total: pack.lines.count)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, prominent ? 18 : 12)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
