//
//  SpookyVoiceWeekCard.swift
//  ReverseSinging
//
//  The Halloween note on the menu, shown only during Spooky Voice Week
//

import SwiftUI

/// Spooky Voice Week on the menu: the vampire, the witch and the pumpkin, the sounds that suit
/// the night, and a way into Sound Imitation, where they are.
///
/// Like `UnlockProCard`, it sits in the menu rather than over it, and the whole card is the
/// button. Without Dubloon Pro the pill carries a padlock, since the tap opens the paywall, as
/// a tap on the padlocked game below it would.
///
/// Its picture is a still from the campaign art, the three of them around a microphone on a
/// stage, framed the way the editor frames a film still: tight radius, hairline, no blur. The
/// copy sits under it on the panel, never over the picture, so it reads in any language.
struct SpookyVoiceWeekCard: View {

    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                stage

                VStack(alignment: .leading, spacing: 6) {
                    Text(SpookyVoiceWeek.dateRangeText())
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsRecord)

                    Text(Strings.Halloween.title)
                        .font(.rsHeadingSmall)
                        .foregroundColor(.rsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Strings.Halloween.homeMessage)
                        .font(.rsBodySmall)
                        .foregroundColor(.rsTextSecondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)

                HStack(spacing: 6) {
                    Text(Strings.Halloween.homeAction)
                        .font(.rsButtonSmall)

                    Image(systemName: isLocked ? "lock.fill" : "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.rsTextOnRed)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                        .fill(Color.rsRecord)
                )
                .padding(.top, 16)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .editorPanel(stroke: Color.rsRecord.opacity(0.35))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Strings.Halloween.title), \(SpookyVoiceWeek.dateRangeText()). \(Strings.Halloween.homeMessage)")
        .accessibilityHint(isLocked ? Strings.Pro.unlockTitle : Strings.Halloween.homeAction)
        .accessibilityAddTraits(.isButton)
    }

    /// The still. 2:1, cut from the In-App Event card so every face and the stage edge stay in.
    private var stage: some View {
        Image("halloween-stage")
            .resizable()
            .aspectRatio(2, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        VStack(spacing: 10) {
            SpookyVoiceWeekCard {}
            SpookyVoiceWeekCard(isLocked: true) {}
        }
        .padding(EditorMetrics.gutter)
    }
    .preferredColorScheme(.dark)
}
