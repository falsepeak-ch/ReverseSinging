//
//  ScoreCard.swift
//  ReverseSinging
//
//  Premium score card with letter grade and attempt playback
//

import SwiftUI

struct ScoreCard: View {
    let score: Double
    let onPlayAttempt: () -> Void
    let onPlayReversedAttempt: () -> Void
    let isPlaying: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Letter grade display
            VStack(spacing: 8) {
                Text("Your Score")
                    .font(.rsBodySmall)
                    .foregroundColor(.white.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(1.5)

                Text(letterGrade)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(gradeDescription)
                    .font(.rsBodyMedium)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)

            // Divider
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.horizontal, 20)

            // Playback buttons
            VStack(spacing: 12) {
                Text("Listen to Your Attempt")
                    .font(.rsBodySmall)
                    .foregroundColor(.white.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(1)

                HStack(spacing: 12) {
                    BigButton(
                        title: "Play Attempt",
                        icon: "play.circle.fill",
                        color: .white,
                        action: onPlayAttempt,
                        isEnabled: !isPlaying,
                        style: .secondary,
                        textFont: .rsButtonSmall
                    )

                    BigButton(
                        title: "Play Reversed",
                        icon: "play.circle.fill",
                        color: .white,
                        action: onPlayReversedAttempt,
                        isEnabled: !isPlaying,
                        style: .secondary,
                        textFont: .rsButtonSmall
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(gradeGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow(.elevated)
        .scaleIn(delay: 0.1)
    }

    // MARK: - Grade Calculation

    private var letterGrade: String {
        switch score {
        case 95...100: return "A+"
        case 90..<95:  return "A"
        case 85..<90:  return "B+"
        case 80..<85:  return "B"
        case 75..<80:  return "C+"
        case 70..<75:  return "C"
        case 60..<70:  return "D"
        default:       return "F"
        }
    }

    private var gradeDescription: String {
        switch score {
        case 95...100: return "Perfect Match!"
        case 90..<95:  return "Excellent!"
        case 85..<90:  return "Great Job!"
        case 80..<85:  return "Very Good!"
        case 75..<80:  return "Good Effort!"
        case 70..<75:  return "Nice Try!"
        case 60..<70:  return "Keep Practicing!"
        default:       return "Try Again!"
        }
    }

    private var gradeGradient: LinearGradient {
        switch score {
        case 90...100:
            // A+/A: Green gradient
            return LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.78, blue: 0.35),  // Light green
                    Color(red: 0.13, green: 0.59, blue: 0.25)   // Dark green
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 80..<90:
            // B: Gold gradient (similar to Voxxa primary)
            return LinearGradient.voxxaPrimaryAdaptive(for: colorScheme)
        case 70..<80:
            // C: Orange gradient
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.65, blue: 0.0),   // Orange
                    Color(red: 0.9, green: 0.45, blue: 0.0)    // Dark orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 60..<70:
            // D: Yellow-orange gradient
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.80, blue: 0.0),   // Gold
                    Color(red: 1.0, green: 0.60, blue: 0.0)    // Dark gold
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            // F: Red gradient
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.26, blue: 0.21),  // Light red
                    Color(red: 0.77, green: 0.12, blue: 0.23)   // Dark red
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ScoreCard(
            score: 97,
            onPlayAttempt: { print("Play attempt") },
            onPlayReversedAttempt: { print("Play reversed") },
            isPlaying: false
        )

        ScoreCard(
            score: 87,
            onPlayAttempt: { print("Play attempt") },
            onPlayReversedAttempt: { print("Play reversed") },
            isPlaying: false
        )

        ScoreCard(
            score: 72,
            onPlayAttempt: { print("Play attempt") },
            onPlayReversedAttempt: { print("Play reversed") },
            isPlaying: false
        )
    }
    .padding()
    .background(Color.rsBackground)
}
