//
//  ReviewBannerCard.swift
//  ReverseSinging
//
//  The note on the menu that thanks a Pro buyer and asks for a review.
//

import SwiftUI

/// A thank-you and an ask, above the games, for people who bought Dubloon Pro.
///
/// It sits in the menu like `TrialEndedCard` rather than over it, so nothing is thrown in front
/// of someone who opened the app to play. The two buttons are the only ways to answer it, and
/// `ReviewBanner` decides when it comes back.
struct ReviewBannerCard: View {

    let onRate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "star.bubble.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.rsTurquoise)
                    .frame(width: 24, height: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(Strings.ReviewBanner.title)
                        .font(.rsButtonMedium)
                        .foregroundColor(.rsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Strings.ReviewBanner.message)
                        .font(.rsMeta)
                        .foregroundColor(.rsTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    HapticManager.shared.light()
                    onDismiss()
                } label: {
                    Text(Strings.ReviewBanner.later)
                        .font(.rsButtonSmall)
                        .foregroundStyle(Color.rsTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                                .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    HapticManager.shared.light()
                    onRate()
                } label: {
                    HStack(spacing: 6) {
                        Text(Strings.ReviewBanner.rate)
                            .font(.rsButtonSmall)

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.rsTextOnTurquoise)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .fill(Color.rsTurquoise)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(stroke: Color.rsTurquoise.opacity(0.35))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        ReviewBannerCard(onRate: {}, onDismiss: {})
            .padding(EditorMetrics.gutter)
    }
    .preferredColorScheme(.dark)
}
