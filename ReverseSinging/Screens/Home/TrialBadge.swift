//
//  TrialBadge.swift
//  ReverseSinging
//
//  The days-left counter in the menu header.
//

import SwiftUI

/// How much of the free window is left, as a tappable pill.
///
/// Shown only during the trial: once the app is bought there is nothing to count,
/// and once the window closes the hard paywall is covering the screen anyway.
///
/// It turns amber on the last day. That is the only visual difference, deliberately
/// — a counter that grows more alarming each day reads as a pressure tactic, and
/// this one has to sit in the header of a menu people open to play a game.
struct TrialBadge: View {

    let daysRemaining: Int
    let action: () -> Void

    private var isLastDay: Bool { daysRemaining <= 1 }

    private var label: String {
        isLastDay
            ? Strings.Pro.Trial.oneDayLeft
            : String(format: Strings.Pro.Trial.daysLeft, daysRemaining)
    }

    private var tint: Color { isLastDay ? .rsCaution : .rsTextSecondary }

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))

                Text(label)
                    .font(.rsCaptionSmall)
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.rsSurface2)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityHint(Strings.Pro.unlockTitle)
    }
}

#Preview {
    VStack(spacing: 12) {
        TrialBadge(daysRemaining: 7) {}
        TrialBadge(daysRemaining: 1) {}
    }
    .padding()
    .background(Color.rsSurface1)
    .preferredColorScheme(.dark)
}
