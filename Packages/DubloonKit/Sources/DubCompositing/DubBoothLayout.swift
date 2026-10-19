//
//  DubBoothLayout.swift
//  DubCompositing
//
//  Where the scene and the booth sit in an exported frame
//

public import CoreGraphics
import Foundation

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
///
/// **Every rect is in the video composition's space**, whose origin is the top left. The
/// waveform strip is the one thing drawn by Core Animation instead, and Core Animation's
/// origin is the bottom left; `DubWaveOverlay` does that flip, and is the only place that
/// should.
public struct DubBoothLayout: Equatable, Sendable {

    /// The size of the exported video.
    public let renderSize: CGSize
    /// Where the scene picture is filled to while the booth is in frame with it.
    public let sceneRect: CGRect
    /// Where the scene sits over the stretches with no booth footage behind them.
    ///
    /// Between two dubbed lines there is genuinely no film of the performer — the camera only
    /// rolls for a take — so a frame that keeps a band reserved for it spends most of its
    /// runtime showing black. In the vertical frames the scene moves to the middle of the
    /// picture area instead and the band closes up; everywhere else this is `sceneRect`.
    public let sceneRectAlone: CGRect
    /// Where the booth is filled to, or nil when the booth is not in this frame.
    public let boothRect: CGRect?
    /// The waveform strip along the foot of the frame, or nil when this frame has none.
    public let waveRect: CGRect?
    /// Whether the booth is drawn after the scene.
    public let boothIsOnTop: Bool
    /// Rounds the booth's corners, in render pixels. Zero everywhere but `vertical`, whose
    /// booth is a picture-in-picture rather than a band.
    public let boothCornerRadius: CGFloat
    /// Where the Dubloon mark goes. Every frame has one, in the corner furthest from the
    /// booth: top-left in `vertical` (the picture-in-picture never takes that corner), and
    /// opposite the booth everywhere else.
    public let watermarkRect: CGRect

    /// The booth inset's height in `corner`, as a fraction of the frame's.
    ///
    /// Sized by height rather than width, because the booth is portrait: 22% of a 16:9 frame's
    /// *width* comes out at 70% of its height, which is not a corner inset, it is a second
    /// picture that happens to be in the corner.
    private static let cornerHeightFraction: CGFloat = 0.34
    /// Its margin from the frame edge, as a fraction of the frame's height.
    private static let cornerMarginFraction: CGFloat = 0.045
    /// The 9:16 canvas the vertical frames render to.
    private static let verticalSize = CGSize(width: 1080, height: 1920)
    /// How much of a vertical frame's height the waveform strip takes.
    private static let waveHeightFraction: CGFloat = 0.115

    /// - Parameters:
    ///   - sceneDisplaySize: the scene picture's size *after* its preferred transform.
    ///   - boothDisplaySize: the booth clip's, likewise. Portrait in practice.
    ///   - pipCorner: where the booth goes in `vertical`. Ignored by every other frame.
    ///   - watermarkAspect: the mark's width over its height, so its rect is the mark's shape.
    public static func make(
        frame: DubBoothFrame,
        sceneDisplaySize: CGSize,
        boothDisplaySize: CGSize,
        pipCorner: DubPipCorner = .bottomRight,
        watermarkAspect: CGFloat = defaultWatermarkAspect
    ) -> DubBoothLayout {
        let base = arrange(
            frame: frame,
            sceneDisplaySize: sceneDisplaySize,
            boothDisplaySize: boothDisplaySize,
            pipCorner: pipCorner
        )
        return base.placingWatermark(frame: frame, aspect: watermarkAspect)
    }

    /// The width over height of the `icon-lettering` mark the app ships.
    public static let defaultWatermarkAspect: CGFloat = 2268.0 / 530.0

    private static func arrange(
        frame: DubBoothFrame,
        sceneDisplaySize: CGSize,
        boothDisplaySize: CGSize,
        pipCorner: DubPipCorner
    ) -> DubBoothLayout {
        let scene = sanitised(sceneDisplaySize, fallback: CGSize(width: 1280, height: 720))
        let booth = sanitised(boothDisplaySize, fallback: CGSize(width: 720, height: 1280))

        switch frame {
        case .vertical:
            return pictureInPicture(scene: scene, booth: booth, corner: pipCorner)

        case .off:
            let full = CGRect(origin: .zero, size: scene)
            return DubBoothLayout(
                renderSize: scene,
                sceneRect: full,
                sceneRectAlone: full,
                boothRect: nil,
                waveRect: nil,
                boothIsOnTop: false
            )

        case .corner:
            // The inset takes the booth's *own* aspect, so filling it is exact and there is no
            // spill to hide. That is what lets the booth sit on top of the scene here.
            let height = (scene.height * cornerHeightFraction).rounded()
            let width = (height * booth.width / booth.height).rounded()
            let margin = (scene.height * cornerMarginFraction).rounded()
            let full = CGRect(origin: .zero, size: scene)

            return DubBoothLayout(
                renderSize: scene,
                sceneRect: full,
                // The scene already has the whole frame; dropping the inset leaves nothing to
                // rearrange.
                sceneRectAlone: full,
                boothRect: CGRect(
                    x: scene.width - width - margin,
                    y: scene.height - height - margin,
                    width: width,
                    height: height
                ),
                waveRect: nil,
                boothIsOnTop: true
            )

        case .stacked, .reaction:
            return vertical(frame: frame, scene: scene)

        case .split:
            // Two halves of a landscape frame. The scene is wider than its half and spills
            // right, into the booth's; the booth fills its half exactly across and is drawn
            // last, so the spill goes behind it.
            let size = scene
            let half = (size.width / 2).rounded()

            return DubBoothLayout(
                renderSize: size,
                sceneRect: CGRect(x: 0, y: 0, width: half, height: size.height),
                // With no booth beside it the scene takes the whole frame back, rather than
                // playing at half width against a black right-hand side.
                sceneRectAlone: CGRect(origin: .zero, size: size),
                boothRect: CGRect(x: half, y: 0, width: size.width - half, height: size.height),
                waveRect: nil,
                boothIsOnTop: true
            )
        }
    }

    // MARK: - Vertical Frames

    /// The two 9:16 frames, which differ only in which band is on top.
    ///
    /// Both reserve a strip at the foot for the waveform and split what is left between the
    /// scene, at its own aspect so filling its band is exact, and the booth, which gets
    /// whatever remains. The booth is portrait and its band is not, so it spills out of the
    /// band on both sides: the scene covers the spill that reaches into the picture, the
    /// waveform strip covers the spill that reaches the foot, and the frame edge takes the
    /// rest. That is why the scene is drawn last in both.
    private static func vertical(frame: DubBoothFrame, scene: CGSize) -> DubBoothLayout {
        let size = verticalSize
        let waveHeight = even(size.height * waveHeightFraction)
        let stageHeight = size.height - waveHeight

        let sceneHeight = min(stageHeight, (size.width * scene.height / scene.width).rounded())
        let boothHeight = stageHeight - sceneHeight

        let waveRect = CGRect(x: 0, y: stageHeight, width: size.width, height: waveHeight)

        // A pack that is already portrait fills the picture area on its own. There is no band
        // left to put a face in, and inventing one would mean cropping the film to make room.
        guard boothHeight >= size.width * 0.25 else {
            let full = CGRect(x: 0, y: 0, width: size.width, height: stageHeight)
            return DubBoothLayout(
                renderSize: size,
                sceneRect: full,
                sceneRectAlone: full,
                boothRect: nil,
                waveRect: waveRect,
                boothIsOnTop: false
            )
        }

        let sceneY: CGFloat = frame == .stacked ? 0 : boothHeight
        let boothY: CGFloat = frame == .stacked ? sceneHeight : 0

        return DubBoothLayout(
            renderSize: size,
            sceneRect: CGRect(x: 0, y: sceneY, width: size.width, height: sceneHeight),
            // Centred in the picture area, so a stretch with nobody in it reads as an
            // ordinary letterboxed vertical post rather than as half a broken one. The scene
            // keeps its size and only moves, which makes the change at each line a cut rather
            // than a resize.
            sceneRectAlone: CGRect(
                x: 0,
                y: ((stageHeight - sceneHeight) / 2).rounded(),
                width: size.width,
                height: sceneHeight
            ),
            boothRect: CGRect(x: 0, y: boothY, width: size.width, height: boothHeight),
            waveRect: waveRect,
            boothIsOnTop: false
        )
    }

    // MARK: - Picture in Picture

    /// The vertical post's proportions, as fractions of the 1080x1920 canvas.
    ///
    /// The insets keep the booth and the mark clear of what TikTok, Reels and Shorts draw over
    /// a video: the status and tab strip along the top, the caption and the action column
    /// along the bottom and the right.
    public enum Vertical {
        public static let sideInset: CGFloat = 0.056
        public static let topInset: CGFloat = 0.08
        public static let bottomInset: CGFloat = 0.10
        /// The picture-in-picture's height. Small enough to be an inset, tall enough to
        /// read a face in.
        public static let pipHeight: CGFloat = 0.21
        /// Its corner radius, as a fraction of its width.
        public static let pipCornerRadius: CGFloat = 0.12
        /// The mark's width.
        public static let watermarkWidth: CGFloat = 0.24
    }

    /// Scene letterboxed in the middle, booth in a corner.
    ///
    /// The booth is anchored to the safe corner rather than to the scene, which is what puts
    /// it inside the black bar whenever the bar is deep enough (any 16:9 scene) and over the
    /// scene's corner when it is not (4:3 and squarer). Either way it never moves during the
    /// export and never reaches the platform's own controls.
    private static func pictureInPicture(scene: CGSize, booth: CGSize, corner: DubPipCorner) -> DubBoothLayout {
        let size = verticalSize

        // Fitted, not filled: the whole of the film is in the post, at its own shape.
        let fit = min(size.width / scene.width, size.height / scene.height)
        let sceneSize = CGSize(width: even(scene.width * fit), height: even(scene.height * fit))
        let sceneRect = CGRect(
            x: even((size.width - sceneSize.width) / 2),
            y: even((size.height - sceneSize.height) / 2),
            width: sceneSize.width,
            height: sceneSize.height
        )

        let pipHeight = even(size.height * Vertical.pipHeight)
        let pipWidth = even(pipHeight * booth.width / booth.height)
        let side = even(size.width * Vertical.sideInset)
        let top = even(size.height * Vertical.topInset)
        let bottom = even(size.height * Vertical.bottomInset)

        let x = corner.isLeft ? side : size.width - side - pipWidth
        let y = corner.isTop ? top : size.height - bottom - pipHeight

        return DubBoothLayout(
            renderSize: size,
            sceneRect: sceneRect,
            // The scene never moves for the booth here: it is the same post with or without
            // a face in the corner.
            sceneRectAlone: sceneRect,
            boothRect: CGRect(x: x, y: y, width: pipWidth, height: pipHeight),
            waveRect: nil,
            boothIsOnTop: true,
            boothCornerRadius: even(pipWidth * Vertical.pipCornerRadius)
        )
    }

    /// Whether the picture-in-picture sits wholly inside a black bar rather than over the film.
    public var boothIsInBar: Bool {
        guard let boothRect, boothCornerRadius > 0 else { return false }
        return boothRect.minY >= sceneRect.maxY || boothRect.maxY <= sceneRect.minY
    }

    // MARK: - Watermark

    /// Puts the mark in its corner, scaled to the output.
    private func placingWatermark(frame: DubBoothFrame, aspect: CGFloat) -> DubBoothLayout {
        let aspect = aspect > 0 ? aspect : Self.defaultWatermarkAspect
        let rect: CGRect

        if frame == .vertical {
            // Top-left, inside the same safe inset the booth keeps.
            let width = Self.even(renderSize.width * Vertical.watermarkWidth)
            rect = CGRect(
                x: Self.even(renderSize.width * Vertical.sideInset),
                y: Self.even(renderSize.height * Vertical.topInset),
                width: width,
                height: (width / aspect).rounded()
            )
        } else {
            // Sized off the short side, so a landscape scene and a 9:16 frame carry the same
            // weight of mark for the size they are seen at.
            let short = min(renderSize.width, renderSize.height)
            let width = Self.even(short * 0.24)
            let height = (width / aspect).rounded()
            let margin = Self.even(short * 0.045)

            // Opposite the booth. Every frame but `reaction` keeps the booth to the bottom or
            // the right, so the mark takes the top-left; `reaction` has the booth across the
            // top, so the mark goes to the bottom-left of the scene, clear of the strip.
            let y = frame == .reaction ? sceneRect.maxY - margin - height : margin
            rect = CGRect(x: margin, y: y, width: width, height: height)
        }

        return DubBoothLayout(
            renderSize: renderSize,
            sceneRect: sceneRect,
            sceneRectAlone: sceneRectAlone,
            boothRect: boothRect,
            waveRect: waveRect,
            boothIsOnTop: boothIsOnTop,
            boothCornerRadius: boothCornerRadius,
            watermarkRect: rect
        )
    }

    private init(
        renderSize: CGSize,
        sceneRect: CGRect,
        sceneRectAlone: CGRect,
        boothRect: CGRect?,
        waveRect: CGRect?,
        boothIsOnTop: Bool,
        boothCornerRadius: CGFloat = 0,
        watermarkRect: CGRect = .zero
    ) {
        self.renderSize = renderSize
        self.sceneRect = sceneRect
        self.sceneRectAlone = sceneRectAlone
        self.boothRect = boothRect
        self.waveRect = waveRect
        self.boothIsOnTop = boothIsOnTop
        self.boothCornerRadius = boothCornerRadius
        self.watermarkRect = watermarkRect
    }

    /// H.264 wants even dimensions, and a zero anywhere here would divide by it later.
    private static func sanitised(_ size: CGSize, fallback: CGSize) -> CGSize {
        guard size.width >= 2, size.height >= 2 else { return fallback }
        return CGSize(width: even(size.width), height: even(size.height))
    }

    private static func even(_ value: CGFloat) -> CGFloat {
        (value / 2).rounded() * 2
    }

    /// The transform that fills `rect` with a source of `displaySize`, centred.
    ///
    /// Scaled by whichever axis needs the most, so the rect is always covered and the overflow
    /// is symmetrical. The caller is responsible for making sure something hides it.
    public static func fillTransform(displaySize: CGSize, into rect: CGRect) -> CGAffineTransform {
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
