//
//  ScoreCard.swift
//  ReverseSinging
//
//  Premium score card with letter grade and attempt playback
//

import SwiftUI

struct ScoreCard: View {
    let score: Double
    @Binding var isVisible: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header with eye button
            HStack {
                Text("Your Score")
                    .font(.rsBodySmall)
                    .foregroundColor(textColor.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(1.5)

                Spacer()

                // Eye toggle button
                Button(action: {
                    withAnimation(.rsSpring) {
                        isVisible.toggle()
                    }
                }) {
                    Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.rsBodyMedium)
                        .foregroundColor(textColor.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, isVisible ? 0 : 20)

            // Collapsible content
            if isVisible {
                VStack(spacing: 8) {
                    Text(letterGrade)
                        .font(.custom("Eugello", size: 72))
                        .foregroundColor(textColor)

                    Text(gradeDescription)
                        .font(.rsBodyMedium)
                        .foregroundColor(textColor.opacity(0.9))
                }
                .transition(.scale.combined(with: .opacity))
                .padding(.bottom, 32)
                .padding(.top, 8)
            }
        }
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
        case 75..<85:  return "B+"
        case 65..<75:  return "B"
        case 55..<65:  return "C+"
        case 45..<55:  return "C"
        case 40..<45:  return "D"
        default:       return "F"
        }
    }

    private var gradeDescription: String {
        switch score {
        case 90...100: return "Perfect Match!"
        case 85..<90:  return "Excellent!"
        case 75..<85:  return "Great Job!"
        case 65..<75:  return "Very Good!"
        case 55..<65:  return "Good Effort!"
        case 45..<55:  return "Nice Try!"
        case 40..<45:  return "Keep Practicing!"
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
        case 65..<85:
            // B+/B: Yellow gradient
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.85, blue: 0.0),   // Bright yellow
                    Color(red: 0.95, green: 0.75, blue: 0.0)   // Golden yellow
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 45..<65:
            // C+/C: Orange gradient
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.65, blue: 0.0),   // Orange
                    Color(red: 0.9, green: 0.45, blue: 0.0)    // Dark orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 40..<45:
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

    private var textColor: Color {
        switch score {
        case 85...100:
            // A+/A (Green background): White text for good contrast
            return .white
        case 65..<85:
            // B+/B (Yellow background): Dark text for readability
            return Color(red: 0.2, green: 0.2, blue: 0.2)  // Charcoal
        case 45..<65:
            // C+/C (Orange background): Dark text for better contrast
            return Color(red: 0.2, green: 0.2, blue: 0.2)  // Charcoal
        case 40..<45:
            // D (Gold background): Dark text for readability
            return Color(red: 0.2, green: 0.2, blue: 0.2)  // Charcoal
        default:
            // F (Red background): White text for good contrast
            return .white
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ScoreCard(score: 97, isVisible: .constant(true))
        ScoreCard(score: 87, isVisible: .constant(false))
        ScoreCard(score: 72, isVisible: .constant(true))
    }
    .padding()
    .background(Color.rsBackground)
}
