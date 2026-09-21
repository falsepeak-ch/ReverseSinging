//
//  TrialEndedCard.swift
//  ReverseSinging
//
//  The note on the menu that says the free trial is over.
//

import SwiftUI

/// Why the games under it are disabled, and the way to open them again.
///
/// It takes the trial counter's place once there is nothing left to count. It sits in the
/// menu rather than over it: the point of showing it here is that nothing is thrown in front
/// of someone who only opened the app, and the paywall waits until they ask for it, by
/// tapping this or a game.
///
/// The whole card is the button. The pill at the bottom is only there to say so.
struct TrialEndedCard: View {

    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.rsCaution)
                        .frame(width: 24, height: 22)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(Strings.Pro.Trial.over)
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
        .accessibilityLabel("\(Strings.Pro.Trial.over). \(Strings.Pro.unlockSubtitle)")
        .accessibilityHint(Strings.Pro.unlockTitle)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        TrialEndedCard {}
            .padding(EditorMetrics.gutter)
    }
    .preferredColorScheme(.dark)
}
