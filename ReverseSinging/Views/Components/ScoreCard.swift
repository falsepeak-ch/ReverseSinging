//
//  ScoreCard.swift
//  ReverseSinging
//
//  Premium score card with letter grade and attempt playback
//

import SwiftUI

struct ScoreCard: View {
    let score: Double
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
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
        .frame(maxWidth: .infinity)
        .background(gradeGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow(.elevated)
        .scaleIn(delay: 0.1)
    }

    // MARK: - Grade Calculation

    private var letterGrade: String {
        switch score {
        case 90...100: return "A+"
        case 85..<90:  return "A"
        case 80..<85:  return "B+"
        case 75..<80:  return "B"
        case 70..<75:  return "C+"
        case 65..<70:  return "C"
        case 60..<65:  return "D"
        default:       return "F"
        }
    }

    private var gradeDescription: String {
        switch score {
        case 90...100: return "Perfect Match!"
        case 85..<90:  return "Excellent!"
        case 80..<85:  return "Great Job!"
        case 75..<80:  return "Very Good!"
        case 70..<75:  return "Good Effort!"
        case 65..<70:  return "Nice Try!"
        case 60..<65:  return "Keep Practicing!"
        default:       return "Try Again!"
        }
    }

    private var gradeGradient: LinearGradient {
        switch score {
        case 85...100:
            // A+/A: Green gradient
            return LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.78, blue: 0.35),  // Light green
                    Color(red: 0.13, green: 0.59, blue: 0.25)   // Dark green
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 75..<85:
            // B+/B: Yellow gradient
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.85, blue: 0.0),   // Bright yellow
                    Color(red: 0.95, green: 0.75, blue: 0.0)   // Golden yellow
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 65..<75:
            // C+/C: Orange gradient
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.65, blue: 0.0),   // Orange
                    Color(red: 0.9, green: 0.45, blue: 0.0)    // Dark orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 60..<65:
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
        ScoreCard(score: 97)
        ScoreCard(score: 87)
        ScoreCard(score: 72)
    }
    .padding()
    .background(Color.rsBackground)
}
