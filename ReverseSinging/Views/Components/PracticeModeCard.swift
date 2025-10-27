//
//  PracticeModeCard.swift
//  ReverseSinging
//
//  Practice mode card encouraging users to listen before recording
//

import SwiftUI

struct PracticeModeCard: View {
    let listenCount: Int
    let onListen: () -> Void
    let onRecord: () -> Void

    private let maxDots = 5
    private let recommendedListens = 2

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "headphones")
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTurquoise)

                Text("Practice Mode")
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsText)

                Spacer()
            }

            // Instructions
            Text("Listen to the reversed audio a few times before recording your attempt!")
                .font(.rsBodyMedium)
                .foregroundColor(.rsSecondaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Listen counter
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<maxDots, id: \.self) { index in
                        Circle()
                            .fill(index < listenCount ? Color.rsTurquoise : Color.rsSecondaryText.opacity(0.2))
                            .frame(width: 12, height: 12)
                            .scaleEffect(index < listenCount ? 1.0 : 0.8)
                            .animation(.rsSpring.delay(Double(index) * 0.05), value: listenCount)
                    }
                }

                Text("Listened \(listenCount)x")
                    .font(.rsCaption)
                    .foregroundColor(.rsSecondaryText)
                    .monospacedDigit()
            }

            // Listen button
            BigButton(
                title: "Listen Again",
                icon: "play.fill",
                color: .rsPlaying,
                action: onListen,
                style: .secondary
            )

            // Ready indicator and record button
            if listenCount >= recommendedListens {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.rsSuccess)
                            .scaleIn(delay: 0.1)

                        Text("Ready to record!")
                            .font(.rsBodyMedium)
                            .foregroundColor(.rsSuccess)
                            .scaleIn(delay: 0.15)
                    }

                    BigButton(
                        title: "Record Attempt",
                        icon: "mic.fill",
                        color: .rsTurquoise,
                        action: onRecord,
                        style: .primary
                    )
                    .scaleIn(delay: 0.2)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Encouragement
                Text("💡 Tip: Listen at least \(recommendedListens)x to improve your chances!")
                    .font(.rsCaption)
                    .foregroundColor(.rsTurquoise)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .transition(.opacity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.rsCardBackground)
                .cardShadow(.card)
        )
        .animation(.rsSpring, value: listenCount)
    }
}

// MARK: - Compact Practice Mode

struct CompactPracticeModeBar: View {
    let listenCount: Int
    let onListen: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "headphones")
                .font(.rsBodyMedium)
                .foregroundColor(.rsTurquoise)

            Text("Listened \(listenCount)x")
                .font(.rsBodyMedium)
                .foregroundColor(.rsText)
                .monospacedDigit()

            Spacer()

            CompactButton(
                title: "Listen",
                icon: "play.fill",
                action: onListen
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.rsSecondaryBackground)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PracticeModeCard(
            listenCount: 1,
            onListen: {},
            onRecord: {}
        )

        PracticeModeCard(
            listenCount: 3,
            onListen: {},
            onRecord: {}
        )

        CompactPracticeModeBar(listenCount: 2, onListen: {})
    }
    .padding()
    .background(Color.rsBackground)
}
