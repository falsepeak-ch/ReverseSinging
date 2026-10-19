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
    /// The pack whose detail is showing beside the list, in the library's split.
    var isSelected = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cardHeight: CGFloat { prominent ? 150 : 74 }
    /// 16:9 on the large card; the phone keeps its 112 pt still so the credit line fits.
    private var thumbnailWidth: CGFloat { prominent ? cardHeight * 16 / 9 : 112 }

    var body: some View {
        Button(action: onOpen) {
            if dynamicTypeSize.isAccessibilitySize {
                // Accessibility sizes: the text needs the full width and whatever height
                // it takes, so the still goes on top instead of beside it.
                VStack(spacing: 0) {
                    DubStillImage(url: pack.iconURL)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    info
                }
            } else {
                HStack(spacing: 0) {
                    thumbnail
                    info
                }
                .frame(height: cardHeight)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
        .editorPanel()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .strokeBorder(Color.rsRecord, lineWidth: 2)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 16:9 thumbnail, like a clip in a bin.
    private var thumbnail: some View {
        DubStillImage(url: pack.iconURL)
            .frame(width: thumbnailWidth, height: cardHeight)
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
