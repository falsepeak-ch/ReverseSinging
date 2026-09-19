//
//  SettingsToggleRow.swift
//  ReverseSinging
//
//  A preference row: what it is and its switch, with the explanation underneath
//

import SwiftUI

/// A preference: what it is and its switch on one line, the explanation on its own line
/// underneath.
///
/// The explanation used to sit beside the switch, sharing the row's width with the icon and
/// the title. A column narrow enough that "Haptic Feedback" broke onto two lines and the
/// descriptions onto three. Given the full width below the row instead, the titles fit on one
/// line and the copy reads as a sentence.
struct SettingsToggleRow<Icon: View>: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                icon()

                Text(title)
                    .font(.rsBodyLarge)
                    .foregroundColor(.rsTextPrimary)
                    // Wraps rather than truncating: some of these titles are a good deal
                    // longer in Spanish and Catalan than they are in English.
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                // Labelled for VoiceOver, hidden on screen. The title beside it is the label.
                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .tint(.rsHighlight)
            }

            Text(subtitle)
                .font(.rsCaption)
                .foregroundColor(.rsTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .editorPanel()
    }
}
