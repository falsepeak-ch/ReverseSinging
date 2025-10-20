//
//  StepIndicator.swift
//  ReverseSinging
//
//  Visual step progress indicator for game workflow
//

import SwiftUI

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int = 3

    private let stepTitles = [
        "Record Original",
        "Record Your Attempt",
        "See Results"
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Step title
            Text("Step \(currentStep)/\(totalSteps): \(stepTitles[currentStep - 1])")
                .font(.rsBodyLarge)
                .foregroundColor(.rsText)
                .animation(.rsSpring, value: currentStep)

            // Progress dots
            HStack(spacing: 12) {
                ForEach(1...totalSteps, id: \.self) { step in
                    stepDot(for: step)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.rsCardBackground)
                .cardShadow(.subtle)
        )
    }

    @ViewBuilder
    private func stepDot(for step: Int) -> some View {
        ZStack {
            if step < currentStep {
                // Completed step - green checkmark
                Circle()
                    .fill(Color.rsSuccess)
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .scaleIn(delay: 0.1)
            } else if step == currentStep {
                // Current step - gold pulsing
                Circle()
                    .fill(Color.rsGold)
                    .frame(width: 32, height: 32)
                    .scaleEffect(1.1)
                    .pulse(color: .rsGold)

                Text("\(step)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.rsTextOnGold)
            } else {
                // Future step - gray
                Circle()
                    .stroke(Color.rsSecondaryText.opacity(0.3), lineWidth: 2)
                    .fill(Color.rsSecondaryBackground)
                    .frame(width: 32, height: 32)

                Text("\(step)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.rsSecondaryText)
            }
        }
        .frame(width: 32, height: 32)
        .animation(.rsSpring, value: currentStep)
    }
}

// MARK: - Compact Step Indicator

struct CompactStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int = 4

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                compactDot(for: step)
            }
        }
    }

    @ViewBuilder
    private func compactDot(for step: Int) -> some View {
        if step < currentStep {
            // Completed
            Circle()
                .fill(Color.rsSuccess)
                .frame(width: 8, height: 8)
        } else if step == currentStep {
            // Current
            Circle()
                .fill(Color.rsGold)
                .frame(width: 10, height: 10)
        } else {
            // Future
            Circle()
                .fill(Color.rsSecondaryText.opacity(0.3))
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StepIndicator(currentStep: 1)
        StepIndicator(currentStep: 2)
        StepIndicator(currentStep: 3)
        StepIndicator(currentStep: 4)

        Divider()

        CompactStepIndicator(currentStep: 2)
    }
    .padding()
    .background(Color.rsBackground)
}
