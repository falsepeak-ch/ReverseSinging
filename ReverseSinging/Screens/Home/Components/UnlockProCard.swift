//
//  UnlockProCard.swift
//  ReverseSinging
//
//  The note on the menu that counts the free takes left, and offers Dubloon Pro.
//

import SwiftUI

/// How many free takes are left across the games under it, and the way to have no limit.
///
/// It sits in the menu rather than over it: nothing is thrown in front of someone who only
/// opened the app. The paywall waits until they tap this, or until a game runs out of takes.
///
/// The whole card is the button. The pill at the bottom is only there to say so.
struct UnlockProCard: View {

    let freeTakesLeft: Int
    let action: () -> Void

    private var title: String { Strings.Pro.freeTakesTitle(left: freeTakesLeft) }

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: freeTakesLeft > 0 ? "sparkles" : "lock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.rsCaution)
                        .frame(width: 24, height: 22)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.rsButtonMedium)
                            .foregroundColor(.rsTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(Strings.Pro.unlockSubtitle)
                            .font(.rsMeta)
                            .foregroundColor(.rsTextSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    Text(Strings.Pro.unlockTitle)
                        .font(.rsButtonSmall)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.rsSurface0)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                        .fill(Color.rsCaution)
                )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .editorPanel(stroke: Color.rsCaution.opacity(0.35))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(Strings.Pro.unlockSubtitle)")
        .accessibilityHint(Strings.Pro.unlockTitle)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        UnlockProCard(freeTakesLeft: 2) {}
            .padding(EditorMetrics.gutter)
    }
    .preferredColorScheme(.dark)
}
