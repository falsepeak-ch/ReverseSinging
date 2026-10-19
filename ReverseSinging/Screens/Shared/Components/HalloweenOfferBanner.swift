//
//  HalloweenOfferBanner.swift
//  ReverseSinging
//
//  The Halloween deal, pinned over the games with a countdown to its last day.
//

import SwiftUI

/// The first year of Dubloon Pro at its Halloween price, and how long is left to take it.
///
/// It stays put above the games rather than scrolling with them, and it is drawn in its own
/// night colours in either appearance: it is a poster for two weeks, not part of the editor.
/// The whole card is the button; it opens the store's own sheet for the yearly plan.
struct HalloweenOfferBanner: View {

    let introPrice: String
    let renewalPrice: String
    let endDate: Date
    var isPurchasing = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(Art.pumpkin)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(-8))
                .frame(width: 64, height: 70)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(Strings.Halloween.badge.uppercased())
                            .font(.system(size: 11, weight: .heavy, design: Font.rsTextDesign))
                            .tracking(0.8)
                            .foregroundStyle(Night.coral)
                            .lineLimit(1)

                        countdown
                    }

                    Text(String(format: Strings.Halloween.title, introPrice))
                        .font(.system(size: 18, weight: .heavy, design: Font.rsTextDesign))
                        .foregroundStyle(Night.cream)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(format: Strings.Halloween.renewal, renewalPrice))
                        .font(.rsMeta)
                        .foregroundStyle(Night.cream.opacity(0.7))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                claim
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backdrop)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Night.coral.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isPurchasing)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Parts

    /// Ticks every second, so the last day feels like the last day.
    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Self.remaining(until: endDate, from: context.date))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Night.night)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Night.cream))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var claim: some View {
        ZStack {
            if isPurchasing {
                ProgressView()
                    .tint(Night.cream)
            } else {
                Text(Strings.Halloween.claim)
                    .font(.system(size: 15, weight: .heavy, design: Font.rsTextDesign))
                    .foregroundStyle(Night.cream)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Night.coral))
    }

    /// A night sky in the characters' own teal.
    private var backdrop: some View {
        LinearGradient(
            colors: [Night.night, Night.teal],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Text

    private var accessibilityText: String {
        [
            Strings.Halloween.badge,
            String(format: Strings.Halloween.title, introPrice),
            String(format: Strings.Halloween.renewal, renewalPrice),
            Self.remaining(until: endDate, from: Date()),
            Strings.Halloween.claim,
        ].joined(separator: ". ")
    }

    /// `13d 4h 12m` while there are days left, then down to the second, in the phone's
    /// language.
    static func remaining(until end: Date, from now: Date) -> String {
        let seconds = max(0, end.timeIntervalSince(now))
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 86_400 ? [.day, .hour, .minute] : [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: seconds) ?? ""
    }
}

/// Each app's own Halloween pumpkin: clay in Dubloon, cartoon in Dubloon the Game.
private enum Art {
    #if DUBLOON_GAME
    static let pumpkin = "game-halloween-pumpkin"
    #else
    static let pumpkin = "halloween-pumpkin"
    #endif
}

/// The banner's own palette: the Halloween characters' teal, cream and coral on a night navy.
private enum Night {
    static let night = Color(red: 0x14 / 255, green: 0x20 / 255, blue: 0x2B / 255)
    static let teal = Color(red: 0x2F / 255, green: 0x57 / 255, blue: 0x5E / 255)
    static let coral = Color(red: 0xE8 / 255, green: 0x48 / 255, blue: 0x3C / 255)
    static let cream = Color(red: 0xF5 / 255, green: 0xF1 / 255, blue: 0xE4 / 255)
}

#Preview {
    ZStack(alignment: .top) {
        Color.rsSurface0.ignoresSafeArea()
        HalloweenOfferBanner(
            introPrice: "$2.99",
            renewalPrice: "$5.99",
            endDate: Date().addingTimeInterval(13 * 86_400 + 3_600 * 4)
        ) {}
        .padding(16)
    }
}
