//
//  HomeVideoInspector.swift
//  DubloonMac
//
//  The loaded clip, and how the finished video is mixed
//

import SwiftUI

struct HomeVideoInspector: View {
    @ObservedObject var dub: HomeVideoDubViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let source = dub.source {
                    ProInspectorSection(title: MacStrings.Panel.clip) {
                        ProInspectorRow(label: MacStrings.Panel.duration, value: source.duration.proShortTime)
                        if source.wasTrimmed {
                            Text(Strings.HomeVideo.trimmed)
                                .font(.rsCaption)
                                .foregroundColor(.rsTextTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                ProInspectorSection(title: MacStrings.Panel.mix) {
                    Toggle(isOn: $dub.keepsOriginalSound) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.HomeVideo.keepOriginal)
                                .font(.rsButtonSmall)
                                .foregroundColor(.rsTextPrimary)
                            Text(dub.source?.hasSound == false ? Strings.HomeVideo.noOriginalSound : Strings.HomeVideo.keepOriginalDetail)
                                .font(.rsCaption)
                                .foregroundColor(.rsTextTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(dub.isBusy || !dub.hasVideo || dub.source?.hasSound == false)
                }

                ProInspectorSection(title: GameMode.homeVideo.title) {
                    Text(GameMode.homeVideo.subtitle)
                        .font(.rsCaption)
                        .foregroundColor(.rsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(MacStrings.HomeVideo.limit)
                        .font(.rsCaption)
                        .foregroundColor(.rsTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .background(Color.rsSurface1)
    }
}
