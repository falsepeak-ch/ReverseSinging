//
//  DubPackGuideModal.swift
//  ReverseSinging
//
//  Step-by-step instructions for getting another dub pack onto the device and into the
//  library: where to find one, downloading it, and importing it. Opened from the row at
//  the foot of the dub library, for the player who has the two starter scenes and no idea
//  where the rest come from.
//

import SwiftUI

struct DubPackGuideModal: View {
    let source: DubContentSource
    /// Called when the user asks to import from here; the library runs its usual gate.
    let onImport: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        EditorModal(title: Strings.DubGuide.title, onClose: onClose) {
            Text(Strings.DubGuide.intro)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextSecondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(1...Strings.DubGuide.stepCount, id: \.self) { number in
                    step(number)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            disclaimer
        } phoneActions: {
            VStack(spacing: 10) {
                BigButton(
                    title: String(format: Strings.DubGate.downloadOpen, source.name),
                    icon: "arrow.up.right",
                    color: .rsHighlight,
                    action: openSource,
                    style: .primary,
                    textFont: .rsButtonMedium
                )

                BigButton(
                    title: Strings.Dub.importPack,
                    icon: "square.and.arrow.down",
                    color: .rsHighlight,
                    action: onImport,
                    style: .secondary,
                    textFont: .rsButtonMedium
                )
            }
        } macActions: {
            Button(Strings.Dub.importPack, action: onImport)
                .platformGlassButton()
            Button(String(format: Strings.DubGate.downloadOpen, source.name), action: openSource)
                .keyboardShortcut(.defaultAction)
                .platformProminentButton()
        }
        .onAppear { AnalyticsManager.shared.trackDubPackGuideOpened() }
    }

    // MARK: - Steps

    private func step(_ number: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.rsMeta.weight(.bold))
                .foregroundColor(.rsSurface0)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.rsHighlight))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.DubGuide.stepTitle(number))
                    .font(.rsBodySmall.weight(.semibold))
                    .foregroundColor(.rsTextPrimary)

                Text(Strings.DubGuide.stepDetail(number))
                    .font(.rsMeta)
                    .foregroundColor(.rsTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Disclaimer

    /// The same two lines as the import gate: the site is not ours, and the rights are the
    /// user's to check. A guide that sends people to download films has to say both.
    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            disclaimerRow(
                icon: "link",
                tint: .rsTextTertiary,
                text: String(format: Strings.DubGate.disclaimerNotAffiliated, source.host)
            )
            disclaimerRow(
                icon: "exclamationmark.triangle.fill",
                tint: .rsCaution,
                text: Strings.DubGate.disclaimerResponsibility
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(.rsSurface2)
    }

    private func disclaimerRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 14)

            Text(text)
                .font(.rsMeta)
                .foregroundColor(.rsTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Behaviour

    private func openSource() {
        AnalyticsManager.shared.trackDubGateExternalSourceOpened(source: source.id)
        openURL(source.url)
    }
}

// MARK: - Row

/// The row pinned to the foot of the dub library that opens the guide. Always there, under
/// the list and under the empty state alike: the question it answers does not go away once
/// the first pack is in.
struct DubPackGuideRow: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.rsHighlight)

                Text(Strings.DubGuide.row)
                    .font(.rsBodySmall.weight(.semibold))
                    .foregroundColor(.rsTextPrimary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.rsTextTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .editorPanel(.rsSurface1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Guide") {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        DubPackGuideModal(source: .example, onImport: {}, onClose: {})
    }
    .preferredColorScheme(.dark)
}
