//
//  DubVideoView.swift
//  ReverseSinging
//
//  The scene video, shown at its own aspect ratio
//

import SwiftUI
import UIKit
import AVFoundation

/// Hosts an `AVPlayerLayer`.
///
/// Deliberately not AVKit's `VideoPlayer`: that ships its own transport controls and a
/// tap-to-scrub overlay, which would sit on top of the picture and compete with the app's
/// own transport bar.
struct DubPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerBackedView {
        let view = PlayerLayerBackedView()
        view.playerLayer.player = player
        // The whole frame, letterboxed, never cropped to fill.
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PlayerLayerBackedView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }

    /// A view whose backing layer *is* the player layer, so it resizes with the view instead
    /// of needing frame bookkeeping in `updateUIView`.
    final class PlayerLayerBackedView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// The picture for a dub screen: the scene video when the pack has one, the per-line still
/// when it doesn't. Packs imported before video support keep working unchanged.
struct DubPicture: View {
    let player: AVPlayer?
    let stillURL: URL?

    var body: some View {
        ZStack {
            Color.black

            if let player {
                DubPlayerLayerView(player: player)
            } else if let stillURL {
                // Fit, not fill: the still stands in for the video and should be framed
                // the same way rather than cropped.
                DubStillImage(url: stillURL, contentMode: .fit)
            }
        }
    }
}
