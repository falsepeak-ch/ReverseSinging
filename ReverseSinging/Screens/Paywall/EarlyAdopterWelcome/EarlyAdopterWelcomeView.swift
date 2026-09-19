//
//  EarlyAdopterWelcomeView.swift
//  ReverseSinging
//
//  The note that tells an early adopter the paywall is not for them.
//

import SwiftUI

/// Shown once, to the people who were using Dubloon before it started charging.
///
/// It exists because the alternative is worse: a user who has had the app for
/// months opens it after an update, sees nothing different, and only finds out
/// months later — from a review or a friend — that everyone else is paying. Told
/// plainly and once, the same fact is a small gift rather than a thing they nearly
/// missed.
///
/// Built out of the editor chrome rather than the usual centred hero stack: the
/// tracked label and its rule, a hairline-ruled panel of labelled rows, timecode
/// figures for the values. The first version of this screen was an illustration
/// over centred text over a pill, which is a layout that would have fitted any app
/// at all — and this is the one screen in Dubloon that should feel like it could
/// only have come from Dubloon. The clapper band across the top is the app's own
/// icon language, and the only warm thing on the screen besides the medal.
///
/// Deliberately not a paywall in reverse. Nothing to buy, nothing to dismiss
/// around, one button.
struct EarlyAdopterWelcomeView: View {

    @StateObject private var viewModel = EarlyAdopterWelcomeViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()

            VStack(spacing: 0) {
                ClapperBand()

                // Scrolled rather than fixed: the message is five lines in English
                // and seven in Catalan, and a screen that shows a gift must not be
                // the one that clips its own last line. Centred while it fits and
                // scrolling once it doesn't, so the short languages aren't left
                // with the column stranded at the top of an empty screen.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            EditorSectionHeader(title: Strings.Pro.EarlyAdopter.badge)

                            medal
                                .padding(.top, 28)

                            Text(Strings.Pro.EarlyAdopter.title)
                                .font(.rsDisplayMedium)
                                .foregroundStyle(Color.rsTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 26)

                            Text(Strings.Pro.EarlyAdopter.message)
                                .font(.rsBodyMedium)
                                .foregroundStyle(Color.rsTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 14)

                            slate
                                .padding(.top, 28)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, EditorMetrics.gutter)
                        .padding(.vertical, 32)
                        .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                }

                footer
            }
        }
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - Pieces

    /// Leading-aligned rather than centred, so it reads as a mark at the head of a
    /// document instead of the hero of a splash screen.
    private var medal: some View {
        Image("settings-free-for-life")
            .resizable()
            .scaledToFit()
            .frame(width: 116, height: 116)
            .accessibilityHidden(true)
    }

    /// The three facts, as a slate reads them: label left, value right, hairline
    /// between. This is what replaced the badge — it says the same thing and
    /// three times as much.
    private var slate: some View {
        VStack(spacing: 0) {
            slateRow(
                label: Strings.Pro.EarlyAdopter.Row.access,
                value: Strings.Pro.EarlyAdopter.Row.accessValue
            )

            EditorRule()

            slateRow(
                label: Strings.Pro.EarlyAdopter.Row.cost,
                value: Strings.Pro.EarlyAdopter.Row.costValue
            )

            EditorRule()

            slateRow(
                label: Strings.Pro.EarlyAdopter.Row.expires,
                value: Strings.Pro.EarlyAdopter.Row.expiresValue,
                tint: .rsGood,
                isConfirmed: true
            )
        }
        .editorPanel()
    }

    private func slateRow(
        label: String,
        value: String,
        tint: Color = .rsTextPrimary,
        isConfirmed: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .editorLabelStyle()

            Spacer(minLength: 8)

            if isConfirmed {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            Text(value)
                .font(.rsTimecode)
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        Button {
            HapticManager.shared.medium()
            dismiss()
        } label: {
            Text(Strings.Pro.EarlyAdopter.confirm)
                .font(.rsButtonLarge)
                .foregroundStyle(Color.rsSurface0)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                        .fill(Color.rsTextPrimary)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, EditorMetrics.gutter)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(Color.rsSurface1.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { EditorRule() }
    }
}

#Preview {
    EarlyAdopterWelcomeView()
        .preferredColorScheme(.dark)
}
