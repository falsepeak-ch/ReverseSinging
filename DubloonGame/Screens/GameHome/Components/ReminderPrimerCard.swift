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
struct ReminderPrimerCard: View {
    let onContinue: () -> Void

    @State private var isIn = false

    var body: some View {
        ZStack {
            Color.gameNavy.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(Color.gameCoral, Color.gameGold)
                    .shadow(color: .gameNavy, radius: 0, x: 0, y: 3)
                    .symbolEffect(.bounce, value: isIn)
                    .padding(.top, 6)

                OutlinedText(text: GameStrings.Reminder.primerTitle, size: 28, color: .white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(GameStrings.Reminder.primerBody)
                    .font(.game(17, weight: .semibold))
                    .foregroundStyle(Color.gameNavy)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                Button(GameStrings.Reminder.primerContinue, action: onContinue)
                    .buttonStyle(GamePillButtonStyle(fill: .gameGold, height: 58))
                    .gameShine()
                    .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .gameCard()
            .padding(.horizontal, 24)
            .scaleEffect(isIn ? 1 : 0.7)
            .opacity(isIn ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { isIn = true }
        }
        .accessibilityAddTraits(.isModal)
    }
}
