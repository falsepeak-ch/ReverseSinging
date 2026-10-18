//
//  ReminderPrimerCard.swift
//  DubloonGame
//
//  The card that explains the reminders, just before iOS asks.
//

import SwiftUI

/// Says what the reminders are, then hands over to iOS's own prompt.
///
/// One button and no way round it, as App Review asks of a permission primer (see the
/// microphone primer): the choice is made in iOS's prompt, never on this card.
///
/// The host, who is the one doing the reminding, waves from a medallion over the card's top
/// edge; the stage behind is dimmed far enough that the host standing on it drops away.
struct ReminderPrimerCard: View {
    let onContinue: () -> Void

    @State private var isIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let medallion: CGFloat = 124

    var body: some View {
        ZStack {
            Color.gameNavy.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text(GameStrings.Reminder.primerTitle)
                    .font(.gameDisplay(28))
                    .foregroundStyle(Color.gameNavy)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(GameStrings.Reminder.primerBody)
                    .font(.game(17, weight: .medium))
                    .foregroundStyle(Color.gameNavy.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onContinue) {
                    Label(GameStrings.Reminder.primerContinue, systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GamePillButtonStyle(fill: .gameGold, height: 58))
                .padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.top, medallion / 2 + 14)
            .padding(.bottom, 20)
            .frame(maxWidth: 360)
            .gameCard(radius: 28, lip: 7)
            .overlay(alignment: .top) {
                portrait.offset(y: -medallion / 2)
            }
            .padding(.horizontal, 24)
            .padding(.top, medallion / 2)
            .scaleEffect(isIn ? 1 : 0.8)
            .opacity(isIn ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { isIn = true; return }
            GameSFX.play(.pop)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { isIn = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    /// The host in a round stage light: a cyan disc, a navy outline and an ivory rim.
    private var portrait: some View {
        Image("game-host-wave-portrait")
            .resizable()
            .scaledToFill()
            .frame(width: medallion, height: medallion)
            .background(
                RadialGradient(colors: [Color(gameHex: 0xBFF1FB), .gameCyan], center: .center, startRadius: 4, endRadius: medallion / 2)
            )
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.gameIvory, lineWidth: 5).padding(4))
            .overlay(Circle().strokeBorder(Color.gameNavy, lineWidth: 4))
            .background(Circle().fill(Color.gameNavy).offset(y: 6))
            .rotationEffect(.degrees(isIn ? 0 : -10))
            .accessibilityHidden(true)
    }
}
