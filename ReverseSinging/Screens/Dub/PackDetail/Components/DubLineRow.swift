//
//  DubLineRow.swift
//  ReverseSinging
//
//  One line of the scene in the pack's list: who says it, whether it's dubbed, how it scored
//

import SwiftUI
import DubScoring

struct DubLineRow: View {
    let line: DubLine
    let isRecorded: Bool
    var score: DubLineScore?
    /// Whether there is a reaction to send along with this line.
    var hasBoothTake: Bool = false
    let characterColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%03d", line.index))
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextTertiary)

            Rectangle()
                .fill(statusColor)
                .frame(width: 2, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    DubCharacterPlate(character: line.character, color: characterColor)

                    Text(line.formattedStartTime)
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextTertiary)
                }

                Text(line.caption)
                    .font(.rsBodySmall)
                    .foregroundColor(isRecorded ? .rsTextPrimary : .rsTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            // Says there is a reaction to send with this line, which is what decides whether
            // sharing it on its own is worth doing at all.
            if hasBoothTake {
                Image(systemName: "video.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.rsTextTertiary)
                    .accessibilityLabel(Strings.Booth.slug)
            }

            // The grade stands in for the tick: a scored line is a recorded line, and
            // "how did it go" is more use than "is there a file".
            if let score {
                DubScoreChip(score: score)
            } else {
                Image(systemName: isRecorded ? "checkmark" : "circle.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isRecorded ? .rsGood : .rsTextTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The spine beside the index: graded once there is a score, plain green for a take that
    /// could not be measured, and inert until something has been recorded.
    private var statusColor: Color {
        if let score { return score.grade.color }
        return isRecorded ? .rsGood : .rsSurface3
    }
}
