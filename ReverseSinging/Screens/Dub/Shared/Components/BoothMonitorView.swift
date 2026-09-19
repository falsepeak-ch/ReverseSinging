//
//  BoothMonitorView.swift
//  ReverseSinging
//
//  The booth feed, framed like a monitor on the picture
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Preview Layer

/// The live camera image, and nothing else.
///
/// A `UIView` whose backing layer *is* the preview layer, rather than one with a sublayer
/// added to it: a sublayer has to be resized by hand on every bounds change, and getting that
/// wrong is what leaves a preview stretched for one frame after a rotation.
struct BoothPreviewView: UIViewRepresentable {

    let session: AVCaptureSession
    /// Flips the image horizontally. The preview only, never the file. See
    /// `BoothCamPreference.mirrorsPreview`.
    var isMirrored: Bool

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        apply(to: view)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== session { view.previewLayer.session = session }
        apply(to: view)
    }

    private func apply(to view: PreviewView) {
        guard let connection = view.previewLayer.connection else { return }
        // The app is portrait-locked, so the preview is too.
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Booth Monitor

/// The booth feed as it sits on the picture: a framed inset with a slug and a record dot.
///
/// Placed in the picture's bottom-right corner, nearest the subtitle plate the performer is
/// actually reading, so glancing at yourself costs no eyeline. Everything else on the record
/// screen keeps its position, which is the whole point of putting it here.
struct BoothMonitor: View {

    @ObservedObject var recorder: BoothRecorder
    @ObservedObject private var preference = BoothCamPreference.shared

    /// Mic level, 0...1. The booth clip is silent, so this is the only thing on the monitor
    /// that says the voice is being heard at all.
    let level: Float
    let isRecording: Bool
    /// A clip to play in place of the live camera, while a take is being reviewed.
    var playbackURL: URL?

    static let width: CGFloat = 96
    static let height: CGFloat = 128

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if let playbackURL {
                    // Never mirrored, whatever the preview preference says: this is the file,
                    // and the file is what an export will show other people. A take reviewed
                    // flipped and then posted unflipped is a surprise at the worst moment.
                    BoothPlaybackView(url: playbackURL)
                } else if recorder.isPreviewing {
                    BoothPreviewView(
                        session: recorder.session,
                        isMirrored: preference.mirrorsPreview
                    )
                } else {
                    // The frame is drawn before the camera warms up, so the monitor fades in
                    // rather than popping into a layout that was not there a moment ago.
                    Color.rsSurface2
                }
            }
            .frame(width: Self.width, height: Self.height)
            .clipped()
            .overlay(alignment: .topLeading) { BoothSlugBadge(isRecording: isRecording) }
            .overlay {
                Rectangle()
                    .strokeBorder(Color.rsStrokeStrong, lineWidth: EditorMetrics.hairline)
            }

            BoothLevelRail(level: CGFloat(level), isActive: isRecording)
                .frame(width: Self.width)
        }
        .animation(.easeInOut(duration: 0.25), value: recorder.isPreviewing)
        .animation(.easeInOut(duration: 0.2), value: playbackURL)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Strings.Booth.monitorAccessibility)
    }

}

// MARK: - Slug

/// The label in the monitor's corner: the booth's name, and whether it is rolling.
struct BoothSlugBadge: View {
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRecording ? Color.rsRecord : Color.rsTextTertiary)
                .frame(width: 5, height: 5)

            Text(Strings.Booth.slug)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundColor(.rsTextPrimary)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Color.rsSurface0.opacity(0.78))
        .padding(5)
    }
}

// MARK: - Reel Monitor

/// The booth footage playing back in step with the scene, in the frame the monitor uses.
///
/// The record screen's monitor swaps between the live camera and one take; this one only
/// ever shows footage, and which footage is `DubBoothReelViewModel`'s business. The dot is never lit,
/// because nothing is being recorded here. Never mirrored either: this is the file, and the
/// file is what an export shows other people.
struct BoothReelMonitor: View {
    @ObservedObject var reel: DubBoothReelViewModel

    var body: some View {
        DubPlayerLayerView(player: reel.player)
            .frame(width: BoothMonitor.width, height: BoothMonitor.height)
            .clipped()
            .overlay(alignment: .topLeading) { BoothSlugBadge(isRecording: false) }
            .overlay {
                Rectangle()
                    .strokeBorder(Color.rsStrokeStrong, lineWidth: EditorMetrics.hairline)
            }
            .accessibilityLabel(Strings.Booth.monitorAccessibility)
    }
}

// MARK: - Playback

/// The booth clip for a take, playing in the monitor's frame.
///
/// Its own `AVPlayer` rather than the scene's: the two are playing different footage at the
/// same moment and the scene picture is driven by a scheduled anchor it does not share.
private struct BoothPlaybackView: View {

    let url: URL

    @State private var player = AVPlayer()

    var body: some View {
        DubPlayerLayerView(player: player)
            .onAppear { start() }
            .onChange(of: url) { _, _ in start() }
            .onDisappear { player.pause() }
    }

    private func start() {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        // The clip is silent, but a player that has not been told so still claims the route.
        player.isMuted = true
        player.seek(to: .zero)
        player.play()
    }
}

// MARK: - Level Rail

/// A thinner cousin of `LevelRail`, sized to sit under a 96pt monitor without shouting.
///
/// The full-size rail is a channel strip and reads as one; at this size the same 14pt bars
/// would weigh more than the picture they sit under.
private struct BoothLevelRail: View {

    let level: CGFloat
    let isActive: Bool

    private let segments = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                let position = CGFloat(index) / CGFloat(segments - 1)
                let isLit = isActive && level >= position

                Rectangle()
                    .fill(isLit ? color(at: position) : Color.rsSurface3)
                    .frame(height: 3)
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    /// The same warning curve the master rail uses, so a hot signal reads the same
    /// everywhere in the app.
    private func color(at position: CGFloat) -> Color {
        if position > 0.86 { return .rsRecord }
        if position > 0.72 { return .rsCaution }
        return .rsTextSecondary
    }
}
