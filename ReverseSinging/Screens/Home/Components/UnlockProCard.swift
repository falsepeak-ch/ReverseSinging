//
//  UnlockProCard.swift
//  ReverseSinging
//
//  The note on the menu that says which games need Dubloon Pro, and offers it.
//

import SwiftUI

/// Why some of the games under it are padlocked, and the way to open them.
///
/// It sits in the menu rather than over it: the point of showing it here is that nothing is
/// thrown in front of someone who only opened the app, and the paywall waits until they ask
/// for it, by tapping this or a locked game.
///
/// The whole card is the button. The pill at the bottom is only there to say so.
struct UnlockProCard: View {

    var title = Strings.Pro.lockedTitle
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.fill")
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
        UnlockProCard {}
            .padding(EditorMetrics.gutter)
    }
    .preferredColorScheme(.dark)
}
