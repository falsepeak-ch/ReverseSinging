//
//  DubBoothLayout.swift
//  ReverseSinging
//
//  Where the scene and the booth sit in an exported frame
//

import Foundation
import CoreGraphics

// MARK: - Frame

/// How the booth is composited into an export.
nonisolated enum DubBoothFrame: String, CaseIterable, Identifiable, Sendable, Codable {
    /// The dub on its own, as it has always exported. The only frame that needs no re-encode.
    case off
    /// A portrait inset in the picture's corner. Output keeps the scene's own shape.
    case corner
    /// Scene above, booth below, rendered 9:16 for a story or a short.
    case stacked
    /// Scene and booth side by side, each filling half a landscape frame.
    case split

    var id: String { rawValue }

    /// Whether choosing this frame means re-encoding rather than remuxing.
    var needsCompositing: Bool { self != .off }
}

// MARK: - Layout

/// The geometry of one exported frame: where each picture goes, and which is drawn last.
///
/// Pure arithmetic, deliberately. Working out where a 720x1280 booth lands inside a 1080x1920
/// canvas is the part of compositing that is easy to get wrong and impossible to eyeball
/// afterwards, so it is separated from AVFoundation and tested on its own.
///
/// **Nothing here crops.** Every rect is filled by scaling the source until it covers the rect,
/// which means the source usually overflows it. Rather than fighting that with crop rectangles,
/// whose coordinate space is a source of bugs, the overflow is *covered*: `boothIsOnTop` says
/// which layer is drawn last, and each layout is arranged so the layer drawn last hides the
/// other's spill. See the per-case notes below.
nonisolated struct DubBoothLayout: Equatable {

    /// The size of the exported video.
    let renderSize: CGSize
    /// Where the scene picture is filled to.
    let sceneRect: CGRect
    /// Where the booth is filled to, or nil when the booth is not in this frame.
    let boothRect: CGRect?
    /// Whether the booth is drawn after the scene.
    let boothIsOnTop: Bool

    /// The booth inset's height in `corner`, as a fraction of the frame's.
    ///
    /// Sized by height rather than width, because the booth is portrait: 22% of a 16:9 frame's
    /// *width* comes out at 70% of its height, which is not a corner inset, it is a second
    /// picture that happens to be in the corner.
    private static let cornerHeightFraction: CGFloat = 0.34
    /// Its margin from the frame edge, as a fraction of the frame's height.
    private static let cornerMarginFraction: CGFloat = 0.045
    /// The 9:16 canvas `stacked` renders to.
    private static let stackedSize = CGSize(width: 1080, height: 1920)

    /// - Parameters:
    ///   - sceneDisplaySize: the scene picture's size *after* its preferred transform.
    ///   - boothDisplaySize: the booth clip's, likewise. Portrait in practice.
    static func make(
        frame: DubBoothFrame,
        sceneDisplaySize: CGSize,
        boothDisplaySize: CGSize
    ) -> DubBoothLayout {
        let scene = sanitised(sceneDisplaySize, fallback: CGSize(width: 1280, height: 720))
        let booth = sanitised(boothDisplaySize, fallback: CGSize(width: 720, height: 1280))

        switch frame {
        case .off:
            return DubBoothLayout(
                renderSize: scene,
                sceneRect: CGRect(origin: .zero, size: scene),
                boothRect: nil,
                boothIsOnTop: false
            )

        case .corner:
            // The inset takes the booth's *own* aspect, so filling it is exact and there is no
            // spill to hide. That is what lets the booth sit on top of the scene here.
            let height = (scene.height * cornerHeightFraction).rounded()
            let width = (height * booth.width / booth.height).rounded()
            let margin = (scene.height * cornerMarginFraction).rounded()

            return DubBoothLayout(
                renderSize: scene,
                sceneRect: CGRect(origin: .zero, size: scene),
                boothRect: CGRect(
                    x: scene.width - width - margin,
                    y: scene.height - height - margin,
                    width: width,
                    height: height
                ),
                boothIsOnTop: true
            )

        case .stacked:
            // Scene across the top at its own aspect, booth filling everything below it.
            // The booth is taller than its band and spills upward into the scene, so the
            // scene is drawn last and covers it.
            let size = stackedSize
            let sceneHeight = (size.width * scene.height / scene.width).rounded()

            return DubBoothLayout(
                renderSize: size,
                sceneRect: CGRect(x: 0, y: 0, width: size.width, height: sceneHeight),
                boothRect: CGRect(
                    x: 0,
                    y: sceneHeight,
                    width: size.width,
                    height: size.height - sceneHeight
                ),
                boothIsOnTop: false
            )

        case .split:
            // Two halves of a landscape frame. The scene is wider than its half and spills
            // right, into the booth's; the booth fills its half exactly across and is drawn
            // last, so the spill goes behind it.
            let size = scene
            let half = (size.width / 2).rounded()

            return DubBoothLayout(
                renderSize: size,
                sceneRect: CGRect(x: 0, y: 0, width: half, height: size.height),
                boothRect: CGRect(x: half, y: 0, width: size.width - half, height: size.height),
                boothIsOnTop: true
            )
        }
    }

    /// H.264 wants even dimensions, and a zero anywhere here would divide by it later.
    private static func sanitised(_ size: CGSize, fallback: CGSize) -> CGSize {
        guard size.width >= 2, size.height >= 2 else { return fallback }
        return CGSize(
            width: (size.width / 2).rounded() * 2,
            height: (size.height / 2).rounded() * 2
        )
    }

    /// The transform that fills `rect` with a source of `displaySize`, centred.
    ///
    /// Scaled by whichever axis needs the most, so the rect is always covered and the overflow
    /// is symmetrical. The caller is responsible for making sure something hides it.
    static func fillTransform(displaySize: CGSize, into rect: CGRect) -> CGAffineTransform {
        guard displaySize.width > 0, displaySize.height > 0 else { return .identity }

        let scale = max(rect.width / displaySize.width, rect.height / displaySize.height)
        let scaled = CGSize(width: displaySize.width * scale, height: displaySize.height * scale)

        return CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(
                CGAffineTransform(
                    translationX: rect.midX - scaled.width / 2,
                    y: rect.midY - scaled.height / 2
                )
            )
    }
}
