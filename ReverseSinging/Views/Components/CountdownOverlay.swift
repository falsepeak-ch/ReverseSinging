//
//  CountdownOverlay.swift
//  ReverseSinging
//
//  The 3-2-1 shown over a screen while the record slate runs
//

import SwiftUI

/// The count that runs between pressing record and the mic opening.
///
/// Large, centred and unmissable: the performer is looking at the picture, not at a label, so
/// this has to read out of the corner of the eye. The last beat turns red because it is the
/// one that matters — it is the beat the recording starts on.
///
/// Never takes touches. The record button underneath stays live so a second press cancels.
struct CountdownOverlay: View {
    /// Beats remaining, or nil when no count is running.
    let value: Int?

    var body: some View {
        ZStack {
            if let value {
                Color.rsSurface0.opacity(0.5)
                    .ignoresSafeArea()

                Text("\(value)")
                    .font(.system(size: 108, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(value == 1 ? .rsRecord : .rsTextPrimary)
                    .contentTransition(.numericText(countsDown: true))
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
                    .accessibilityLabel(Strings.Main.State.countingIn)
                    .accessibilityValue("\(value)")
            }
        }
        .animation(.easeOut(duration: 0.18), value: value)
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        CountdownOverlay(value: 3)
    }
}
