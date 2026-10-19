//
//  HalloweenScenesSection.swift
//  ReverseSinging
//
//  Scary movie scenes to dub for Halloween, at the top of the dub library while the Halloween
//  banner is switched on: a banner saying what they are, then one row per scene, each opening
//  its pack's own page on GameBanana.
//

import SwiftUI

struct HalloweenScenesSection: View {
    let scenes: [HalloweenScene]

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 8) {
            banner

            ForEach(scenes) { scene in
                row(scene)
            }
        }
    }

    // MARK: - Banner

    /// What the list is and how a scene gets in, and the guide's two lines: GameBanana is not
    /// ours, and the rights are the user's to check.
    private var banner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image("halloween-pumpkin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-8))
                    .accessibilityHidden(true)

                Text(Strings.HalloweenScenes.title)
                    .font(.rsBodySmall.weight(.bold))
                    .foregroundColor(.rsTextPrimary)
            }

            Text(Strings.HalloweenScenes.intro)
                .font(.rsMeta)
                .foregroundColor(.rsTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(format: Strings.DubGate.disclaimerNotAffiliated, DubContentSource.example.host)
                 + " " + Strings.DubGate.disclaimerResponsibility)
                .font(.rsMeta)
                .foregroundColor(.rsTextTertiary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(.rsSurface2)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Scenes

    private func row(_ scene: HalloweenScene) -> some View {
        Button {
            HapticManager.shared.light()
            open(scene)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(scene.film)
                        .font(.rsBodySmall.weight(.semibold))
                        .foregroundColor(.rsTextPrimary)

                    Text(scene.scene)
                        .font(.rsMeta)
                        .foregroundColor(.rsTextSecondary)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.rsHighlight)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .editorPanel(.rsSurface1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(format: Strings.DubGate.downloadOpen, DubContentSource.example.name))
    }

    private func open(_ scene: HalloweenScene) {
        AnalyticsManager.shared.trackCustomEvent(
            name: "halloween_scene_opened",
            parameters: ["mod_id": scene.id]
        )
        openURL(scene.url)
    }
}

// MARK: - Previews

#Preview("Halloween scenes") {
    ScrollView {
        HalloweenScenesSection(scenes: HalloweenScenes.all)
            .padding(16)
    }
    .background(Color.rsSurface0)
    .preferredColorScheme(.dark)
}
