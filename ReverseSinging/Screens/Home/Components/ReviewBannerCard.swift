//
//  ReviewBannerCard.swift
//  ReverseSinging
//
//  The note on the menu that asks how Dubloon is going, in stars.
//

import SwiftUI

/// A thank-you and a question, above the games: how many stars?
///
/// It sits in the menu like `TrialEndedCard` rather than over it, so nothing is thrown in front
/// of someone who opened the app to play. A star or "Not now" are the only ways to answer it.
/// What a rating leads to, and when the note comes back, are `ReviewBanner`'s to decide.
struct ReviewBannerCard: View {

    /// Whether this is the thank-you for buying Pro, or the note for a free player who is
    /// clearly having a good time.
    var thanksForPro = true
    /// The rating last tapped, which stays lit while its dialog is up. Zero for none.
    var stars = 0
    let onRate: (Int) -> Void
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
                    Text(thanksForPro ? Strings.ReviewBanner.title : Strings.ReviewBanner.fanTitle)
                        .font(.rsButtonMedium)
                        .foregroundColor(.rsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Strings.ReviewBanner.prompt)
                        .font(.rsMeta)
                        .foregroundColor(.rsTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                ForEach(1...ReviewBanner.maximumStars, id: \.self) { star in
                    Button {
                        HapticManager.shared.light()
                        onRate(star)
                    } label: {
                        Image(systemName: star <= stars ? "star.fill" : "star")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(star <= stars ? Color.rsTurquoise : Color.rsTextTertiary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(String(format: Strings.ReviewBanner.starLabel, star))
                }
            }
            .animation(.rsQuick, value: stars)

            Button {
                HapticManager.shared.light()
                onDismiss()
            } label: {
                Text(Strings.ReviewBanner.later)
                    .font(.rsButtonSmall)
                    .foregroundStyle(Color.rsTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
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
        ReviewBannerCard(stars: 4, onRate: { _ in }, onDismiss: {})
            .padding(EditorMetrics.gutter)
    }
    .preferredColorScheme(.dark)
}
