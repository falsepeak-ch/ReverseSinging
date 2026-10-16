//
//  DubVideoView.swift
//  ReverseSinging
//
//  The scene video, shown at its own aspect ratio
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import AVFoundation

/// Hosts an `AVPlayerLayer`.
///
/// Deliberately not AVKit's `VideoPlayer`: that ships its own transport controls and a
/// tap-to-scrub overlay, which would sit on top of the picture and compete with the app's
/// own transport bar.
#if os(iOS)
struct DubPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    /// Fill the frame (cropping the edges) rather than letterbox it.
    var fills = false

    func makeUIView(context: Context) -> PlayerLayerBackedView {
        let view = PlayerLayerBackedView()
        view.playerLayer.player = player
        // The whole frame, letterboxed, unless the pane asks to be filled.
        view.playerLayer.videoGravity = fills ? .resizeAspectFill : .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PlayerLayerBackedView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
        view.playerLayer.videoGravity = fills ? .resizeAspectFill : .resizeAspect
    }

    /// A view whose backing layer *is* the player layer, so it resizes with the view instead
    /// of needing frame bookkeeping in `updateUIView`.
    final class PlayerLayerBackedView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
#else
struct DubPlayerLayerView: NSViewRepresentable {
    let player: AVPlayer
    var fills = false

    func makeNSView(context: Context) -> PlayerLayerBackedView {
        let view = PlayerLayerBackedView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.backgroundColor = CGColor(gray: 0, alpha: 1)
        return view
    }

    func updateNSView(_ view: PlayerLayerBackedView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }

    /// The Mac spelling of the same idea: a layer-hosting view whose layer is the player's.
    final class PlayerLayerBackedView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer = playerLayer
        }

        required init?(coder: NSCoder) { nil }
    }
}
#endif

/// The picture for a dub screen: the scene video when the pack has one, the per-line still
/// when it doesn't. Packs imported before video support keep working unchanged.
struct DubPicture: View {
    let player: AVPlayer?
    let stillURL: URL?
    /// Fill the pane, cropping the edges, rather than letterbox: for a pane shaped by the
    /// display rather than by the scene (the booth on iPhone Duo open).
    var fills = false

    var body: some View {
        ZStack {
            Color.black

            if let player {
                DubPlayerLayerView(player: player, fills: fills)
            } else if let stillURL {
                // Framed as the video is: fit where the video is letterboxed, fill where
                // it fills.
                DubStillImage(url: stillURL, contentMode: fills ? .fill : .fit)
            }
        }
    }
}
