//
//  HomeVideoIntro.swift
//  ReverseSinging
//
//  What Home Video Dub is, how it differs from the movie dub, and the way in
//

import PhotosUI
import SwiftUI

/// Shown until a video is picked. Two games have "dub" in their name, so this says plainly
/// which one this is before asking for anything.
struct HomeVideoIntro: View {
    @Binding var pickerItem: PhotosPickerItem?
    let isImporting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 14) {
                Image(GameMode.homeVideo.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                Text(Strings.HomeVideo.introTitle)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)
                    .multilineTextAlignment(.center)

                Text(Strings.HomeVideo.introBody)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            steps

            comparison

            VStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .videos, preferredItemEncoding: .current) {
                    HStack(spacing: 10) {
                        if isImporting {
                            ProgressView().tint(.rsSurface0)
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                        Text(isImporting ? Strings.HomeVideo.importing : Strings.HomeVideo.choose)
                    }
                    .font(.rsButtonMedium)
                    .foregroundColor(.rsSurface0)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .fill(Color.rsTextPrimary)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isImporting)

                Text(Strings.HomeVideo.limit)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            step(1, Strings.HomeVideo.stepPick)
            step(2, Strings.HomeVideo.stepRecord)
            step(3, Strings.HomeVideo.stepShare)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(.rsSurface1)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsSurface0)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.rsTextSecondary))
            Text(text)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The one thing people mix up: this is not the movie-scene game.
    private var comparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorSectionHeader(title: Strings.HomeVideo.compareTitle)

            compareRow(
                image: GameMode.homeVideo.image,
                title: GameMode.homeVideo.title,
                detail: Strings.HomeVideo.compareHome,
                isThisOne: true
            )
            compareRow(
                image: GameMode.dub.image,
                title: GameMode.dub.title,
                detail: Strings.HomeVideo.compareDub,
                isThisOne: false
            )
        }
    }

    private func compareRow(image: String, title: String, detail: String, isThisOne: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.rsButtonSmall)
                        .foregroundColor(.rsTextPrimary)
                    if isThisOne {
                        Text(Strings.Main.Mode.free)
                            .font(.rsLabelSmall)
                            .textCase(.uppercase)
                            .foregroundColor(.rsSurface0)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.rsTextSecondary))
                    }
                }
                Text(detail)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(isThisOne ? .rsSurface2 : .rsSurface1)
    }
}
