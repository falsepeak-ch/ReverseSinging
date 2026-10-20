//
//  HalloweenDealModal.swift
//  ReverseSinging
//
//  What the Halloween plan is, and the terms it is sold under, before the store's sheet
//

import SwiftUI

/// The Halloween plan's terms, said in full before anything is bought.
///
/// The banner is a poster, not a purchase: App Review (guideline 3.1.2) wants an
/// auto-renewing subscription's name, length, price and renewal, and links to the Terms of
/// Use and the Privacy Policy, shown where it is sold. This is that place. Continue opens the
/// store's own sheet; Not now and the close key just put it away.
struct HalloweenDealModal: View {

    let deal: HalloweenDeal
    let onContinue: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        EditorModal(title: Strings.HalloweenDeal.badge, onClose: onClose) {
            VStack(spacing: 14) {
                Text(Strings.HalloweenDeal.planName)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)
                    .multilineTextAlignment(.center)

                Text(String(format: Strings.HalloweenDeal.priceLine, deal.introPrice, deal.renewalPrice))
                    .font(.rsBodyMedium)
                    .foregroundColor(.rsTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(format: Strings.HalloweenDeal.terms, deal.renewalPrice))
                    .font(.rsCaption)
                    .foregroundColor(.rsTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Button(Strings.Pro.Fallback.terms) { openURL(AppLinks.termsOfUse) }
                    Button(Strings.Settings.privacyPolicy) { openURL(AppLinks.privacyPolicy) }
                }
                .font(.rsCaptionSmall)
                .foregroundStyle(Color.rsTextTertiary)
            }
        } phoneActions: {
            BigButton(
                title: Strings.HalloweenDeal.continueTitle,
                icon: "sparkles",
                color: .rsTurquoise,
                action: onContinue,
                style: .primary,
                textFont: .rsButtonMedium
            )
        } macActions: {
            Button(Strings.HalloweenDeal.continueTitle, action: onContinue)
                .keyboardShortcut(.defaultAction)
                .platformProminentButton()
        }
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        HalloweenDealModal(
            deal: HalloweenDeal(introPrice: "$2.99", renewalPrice: "$12.99", endDate: Date()),
            onContinue: {},
            onClose: {}
        )
    }
}
