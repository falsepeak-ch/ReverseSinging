//
//  GameBoothMonitor.swift
//  DubloonGame
//
//  Booth Cam on the game's stage: the player's face in a small TV, and the key that turns it on.
//

import SwiftUI

/// The front camera as a little on-air monitor: an ivory-rimmed screen with a navy outline,
/// a tag that turns red while the mic is open, and the take's footage in place of the
/// camera while a take is being reviewed.
struct GameBoothMonitor: View {
    @ObservedObject var recorder: BoothRecorder
    @ObservedObject private var preference = BoothCamPreference.shared
    let isRecording: Bool
    var playbackURL: URL?
    var width: CGFloat = 92

    var body: some View {
        ZStack {
            if let playbackURL {
                // The file, never mirrored: what an export will show.
                BoothPlaybackView(url: playbackURL)
            } else if recorder.isPreviewing {
                BoothPreviewView(session: recorder.session, isMirrored: preference.mirrorsPreview)
            } else {
                Color.gameNavy
                Image(systemName: "video.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.gameCyan.opacity(0.6))
            }
        }
        .frame(width: width, height: width * 4 / 3)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topLeading) {
            HStack(spacing: 3) {
                Circle().fill(isRecording ? Color.gameRed : Color.gameIvory.opacity(0.7)).frame(width: 6, height: 6)
                Text(Strings.Booth.slug.uppercased())
                    .font(.game(9, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(isRecording ? Color.gameRed.opacity(0.85) : Color.black.opacity(0.55)))
            .padding(6)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.gameIvory))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.gameNavy, lineWidth: 3))
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.gameNavy).offset(y: 4))
        .animation(.easeInOut(duration: 0.25), value: recorder.isPreviewing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Strings.Booth.monitorAccessibility)
    }
}

/// The round key that turns Booth Cam on and off: a camera, lit cyan while it is on.
struct GameBoothKey: View {
    @ObservedObject private var preference = BoothCamPreference.shared
    var diameter: CGFloat = 44
    let action: () -> Void

    var body: some View {
        GameRoundButton(
            symbol: preference.isEnabled ? "video.fill" : "video.slash.fill",
            label: Strings.Booth.settingsSection,
            diameter: diameter,
            fill: preference.isEnabled ? .gameCyan : .gameIvory,
            action: action
        )
        .accessibilityAddTraits(preference.isEnabled ? .isSelected : [])
    }
}

/// A video rendering: a chunky bar filling with cyan, and the percentage.
struct GameExportProgress: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gameNavy.opacity(0.5))
                    Capsule()
                        .fill(Color.gameCyan)
                        .frame(width: max(24, proxy.size.width * progress))
                        .animation(.easeOut(duration: 0.2), value: progress)
                    Capsule().strokeBorder(Color.gameNavy, lineWidth: 3)
                }
            }
            .frame(height: 24)
            Text("\(Strings.Imitate.rendering) \(Int(progress * 100))%")
                .font(.game(15, weight: .bold))
                .foregroundStyle(Color.gameCyan)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Strings.Imitate.rendering)
        .accessibilityValue("\(Int(progress * 100))%")
    }
}
