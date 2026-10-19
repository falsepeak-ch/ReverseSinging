//
//  OfferBannerCard.swift
//  ReverseSinging
//
//  The note on the menu that names a subscription offer this person can take right now.
//

import SwiftUI

/// Takes the place of `UnlockProCard` while there is a real offer to make: a free trial for
/// someone new, or a win-back offer for someone whose subscription ran out. The words come
/// from the store, price and period included, so it never promises what the App Store
/// would not give.
struct OfferBannerCard: View {

    let offer: SubscriptionOffer
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                HapticManager.shared.light()
                onTap()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: offer.kind == .winBack ? "arrow.uturn.backward.circle.fill" : "gift.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.rsCaution)
                        .frame(width: 24, height: 22)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(offer.title)
                            .font(.rsButtonMedium)
                            .foregroundColor(.rsTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(offer.subtitle)
                            .font(.rsMeta)
                            .foregroundColor(.rsTextSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(offer.title). \(offer.subtitle)")
            .accessibilityAddTraits(.isButton)

            HStack(spacing: 8) {
                Button {
                    HapticManager.shared.light()
                    onDismiss()
                } label: {
                    Text(Strings.Offer.dismiss)
                        .font(.rsButtonSmall)
                        .foregroundStyle(Color.rsTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    HapticManager.shared.light()
                    onTap()
                } label: {
                    HStack(spacing: 6) {
                        Text(Strings.Offer.cta)
                            .font(.rsButtonSmall)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.rsSurface0)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .fill(Color.rsCaution)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(stroke: Color.rsCaution.opacity(0.35))
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        OfferBannerCard(
            offer: SubscriptionOffer(kind: .intro, productID: "monthly",
                                     title: "Try Dubloon Pro free for 1 week",
                                     subtitle: "Then $2.99 / 1 month. Cancel anytime."),
            onTap: {}, onDismiss: {}
        )
        .padding(EditorMetrics.gutter)
    }
    .preferredColorScheme(.dark)
}
