//
//  GameModeRow.swift
//  ReverseSinging
//
//  A row on the home menu: one game, tapped to push into it.
//

import SwiftUI

/// A menu row for one game. The chevron and the full-width shape are what say
/// "this goes somewhere". The home screen picks a game. It does not play one.
///
/// Locked, once the trial is over, it is dimmed and the chevron becomes a padlock. It stays a
/// button: a disabled row that swallowed the tap would leave the user guessing why, so the tap
/// goes to the caller, which answers with the paywall.
struct GameModeRow: View {
    let mode: GameMode
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 16) {
                Image(mode.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .saturation(isLocked ? 0 : 1)
                    .frame(width: 68, height: 68)
                    .background(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .fill(Color.rsSurface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.title)
                        .font(.rsButtonMedium)
                        .foregroundColor(isLocked ? .rsTextSecondary : .rsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(mode.subtitle)
                        .font(.rsMeta)
                        .foregroundColor(.rsTextTertiary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rsTextTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isLocked ? 0.5 : 1)
            .editorPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityValue(isLocked ? Strings.Pro.Trial.over : "")
        .accessibilityHint(isLocked ? Strings.Pro.unlockTitle : mode.subtitle)
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        VStack(spacing: 10) {
            ForEach(GameMode.allCases) { mode in
                GameModeRow(mode: mode) {}
            }
            ForEach(GameMode.allCases) { mode in
                GameModeRow(mode: mode, isLocked: true) {}
            }
        }
        .padding(EditorMetrics.gutter)
    }
}
