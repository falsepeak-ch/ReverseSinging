//
//  DubFrameCompositor.swift
//  ReverseSinging
//
//  Draws one export frame: the pictures, the rounded booth, the mark
//

import AVFoundation
import CoreImage
import CoreGraphics
import DubCompositing

// MARK: - Instruction

/// What one stretch of an export looks like: which tracks go where, back to front, and the
/// mark over the top.
///
/// A custom instruction rather than `AVMutableVideoCompositionLayerInstruction`, because layer
/// instructions can only transform, crop and fade: they cannot round a corner, draw a border or
/// lay a logo with transparency over the picture. The obvious tool for the last of those,
/// `AVVideoCompositionCoreAnimationTool`, crashes the export when its per-layer surfaces cannot
/// be allocated (always, on the Simulator); see `DubWaveOverlay`. So every composited export
/// goes through `DubFrameCompositor`, which draws with Core Image on the GPU.
nonisolated final class DubFrameInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {

    /// One picture in the frame.
    struct Layer {
        let trackID: CMPersistentTrackID
        /// Maps the source's natural pixels into the render, top-left origin, exactly as a
        /// layer instruction's transform would.
        let transform: CGAffineTransform
        /// The rect the picture is filled into. A rounded inset is also cut to it; a band is
        /// not, and relies on the layer drawn after it to cover its overflow.
        let clip: CGRect
        /// When non-zero the clip's corners are rounded, and the picture gets its border
        /// and shadow. See `DubFrameDecor`.
        let cornerRadius: CGFloat
        /// Fill `clip` from whatever size each frame turns out to be, instead of `transform`.
        ///
        /// For the booth: its clips are written upright with the rotation baked in, so a take
        /// filmed with an iPhone Duo open in landscape is a landscape clip and the next one,
        /// closed, is portrait. They share one composition track, and a transform worked out
        /// from the first would squash the other.
        var fillsFromSource = false
    }

    /// The mark: an image, where it goes, and how strongly.
    struct Watermark {
        let image: CGImage
        let rect: CGRect
        let opacity: CGFloat
    }

    let timeRange: CMTimeRange
    let enablePostProcessing = false
    /// Nothing moves inside an instruction, so a frame whose sources have not changed can be
    /// reused.
    let containsTweening = false
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid

    let renderSize: CGSize
    /// Back to front.
    let layers: [Layer]
    let watermark: Watermark?
    let decor: DubFrameDecor?

    init(
        timeRange: CMTimeRange,
        renderSize: CGSize,
        layers: [Layer],
        watermark: Watermark?,
        decor: DubFrameDecor?
    ) {
        self.timeRange = timeRange
        self.renderSize = renderSize
        self.layers = layers
        self.watermark = watermark
        self.decor = decor
        requiredSourceTrackIDs = Array(Set(layers.map(\.trackID))).map { NSNumber(value: $0) }
        super.init()
    }
}

// MARK: - Decor

/// The picture-in-picture's border and shadow, drawn once per export with Core Graphics and
/// laid under and over the booth on every frame.
///
/// Dubloon's booth monitor is a thin strong-stroke frame on a dark surface; at 1080x1920 that
/// reads as a cream hairline a few pixels thick, the logo's own cream, over a soft shadow that
/// lifts the inset off the film when it overlaps it.
nonisolated final class DubFrameDecor: @unchecked Sendable {

    let rect: CGRect
    let shadow: CIImage
    let border: CIImage

    /// The cream of the Dubloon lettering.
    static let borderColor = CGColor(srgbRed: 0.93, green: 0.91, blue: 0.80, alpha: 0.92)

    init?(rect: CGRect, cornerRadius: CGFloat, renderSize: CGSize) {
        self.rect = rect
        let lineWidth = max(2, (rect.width * 0.018).rounded())
        let blur = max(6, (rect.width * 0.08).rounded())

        // The shadow image is the rect plus room for its blur, so it can be placed by offset.
        let pad = blur * 2
        let shadowSize = CGSize(width: rect.width + pad * 2, height: rect.height + pad * 2)
        guard let shadowImage = Self.draw(size: shadowSize, { context in
            context.setShadow(
                offset: CGSize(width: 0, height: -blur * 0.35),
                blur: blur,
                color: CGColor(gray: 0, alpha: 0.65)
            )
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.addPath(CGPath(
                roundedRect: CGRect(x: pad, y: pad, width: rect.width, height: rect.height),
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            ))
            context.fillPath()
        }) else { return nil }

        guard let borderImage = Self.draw(size: rect.size, { context in
            context.setStrokeColor(Self.borderColor)
            context.setLineWidth(lineWidth)
            let inset = lineWidth / 2
            context.addPath(CGPath(
                roundedRect: CGRect(origin: .zero, size: rect.size).insetBy(dx: inset, dy: inset),
                cornerWidth: max(0, cornerRadius - inset),
                cornerHeight: max(0, cornerRadius - inset),
                transform: nil
            ))
            context.strokePath()
        }) else { return nil }

        // Both images are placed in Core Image space, whose origin is the bottom left.
        let ciRect = DubFrameCompositor.ciRect(rect, renderHeight: renderSize.height)
        shadow = CIImage(cgImage: shadowImage)
            .transformed(by: CGAffineTransform(translationX: ciRect.minX - pad, y: ciRect.minY - pad))
        border = CIImage(cgImage: borderImage)
            .transformed(by: CGAffineTransform(translationX: ciRect.minX, y: ciRect.minY))
    }

    private static func draw(size: CGSize, _ body: (CGContext) -> Void) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int(size.width.rounded(.up)),
            height: Int(size.height.rounded(.up)),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        body(context)
        return context.makeImage()
    }
}

// MARK: - Compositor

/// Renders `DubFrameInstruction`s.
///
/// Stateless apart from the Core Image context, which is expensive to make and safe to share.
/// Requests are rendered on one serial queue, in the order AVFoundation asks for them.
nonisolated final class DubFrameCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {

    private static let context = CIContext(options: [
        .cacheIntermediates: false,
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any
    ])
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    private let queue = DispatchQueue(label: "ch.falsepeak.dubloon.export.compositor")

    let sourcePixelBufferAttributes: [String: any Sendable]? = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int]()
    ]

    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int]()
    ]

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        nonisolated(unsafe) let request = request
        queue.async {
            guard let instruction = request.videoCompositionInstruction as? DubFrameInstruction,
                  let output = request.renderContext.newPixelBuffer() else {
                request.finish(with: DubExportError.renderSetupFailed)
                return
            }

            let image = Self.compose(instruction) { request.sourceFrame(byTrackID: $0) }
            do {
                try Self.render(image, size: instruction.renderSize, into: output)
                request.finish(withComposedVideoFrame: output)
            } catch {
                request.finish(with: error)
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {}

    /// Used when the GPU will not render: a device under memory pressure, or a busy Simulator.
    private static let softwareContext = CIContext(options: [
        .useSoftwareRenderer: true,
        .cacheIntermediates: false,
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any
    ])

    /// Renders and *waits for the result*, so a render that failed is known about.
    ///
    /// `CIContext.render(_:to:)` reports nothing: a frame the GPU could not draw leaves the
    /// buffer holding whatever it held, and that went into the file as a black or garbage
    /// frame. The task API throws instead, and the frame is drawn again on the CPU.
    private static func render(_ image: CIImage, size: CGSize, into buffer: CVPixelBuffer) throws {
        let destination = CIRenderDestination(pixelBuffer: buffer)
        destination.colorSpace = colorSpace
        let bounds = CGRect(origin: .zero, size: size)

        do {
            _ = try context.startTask(toRender: image, from: bounds, to: destination, at: .zero).waitUntilCompleted()
        } catch {
            _ = try softwareContext.startTask(toRender: image, from: bounds, to: destination, at: .zero).waitUntilCompleted()
        }
    }

    // MARK: Drawing

    /// One frame, as a Core Image recipe. A track with no frame at this instant (a booth clip
    /// that starts a hair after its line, a film shorter than its manifest) is skipped rather
    /// than failing the frame, and the black under it shows.
    static func compose(
        _ instruction: DubFrameInstruction,
        source: (CMPersistentTrackID) -> CVPixelBuffer?
    ) -> CIImage {
        let size = instruction.renderSize
        let bounds = CGRect(origin: .zero, size: size)
        var image = CIImage(color: .black).cropped(to: bounds)

        for layer in instruction.layers {
            guard let buffer = source(layer.trackID) else { continue }

            let sourceImage = CIImage(cvPixelBuffer: buffer)
            let sourceHeight = sourceImage.extent.height
            let clip = ciRect(layer.clip, renderHeight: size.height)
            let transform = layer.fillsFromSource
                ? DubBoothLayout.fillTransform(displaySize: sourceImage.extent.size, into: layer.clip)
                : layer.transform

            // The layer's transform is in top-left space on both sides; Core Image's origin is
            // the bottom left on both. Flip in, transform, flip out.
            let flipIn = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: sourceHeight)
            let flipOut = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
            var picture = sourceImage
                .transformed(by: flipIn.concatenating(transform).concatenating(flipOut))
                // Only an inset is cut to its rect. The bands keep the overflow behaviour the
                // layouts were designed around (see `DubBoothLayout`): whatever is drawn after
                // a picture covers its spill, so a frame looks exactly as it always has.
                .cropped(to: layer.cornerRadius > 0 ? clip : bounds)

            if layer.cornerRadius > 0 {
                let mask = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
                    "inputExtent": CIVector(cgRect: clip),
                    "inputRadius": layer.cornerRadius,
                    "inputColor": CIColor.white
                ])?.outputImage

                if let mask {
                    picture = picture.applyingFilter("CIBlendWithMask", parameters: [
                        kCIInputBackgroundImageKey: CIImage.empty(),
                        kCIInputMaskImageKey: mask
                    ])
                }
                if let decor = instruction.decor {
                    image = decor.shadow.composited(over: image)
                    image = decor.border.composited(over: picture.composited(over: image))
                    continue
                }
            }

            image = picture.composited(over: image)
        }

        if let watermark = instruction.watermark {
            let rect = ciRect(watermark.rect, renderHeight: size.height)
            let logo = CIImage(cgImage: watermark.image)
            let scale = min(rect.width / logo.extent.width, rect.height / logo.extent.height)
            let placed = logo
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: watermark.opacity)
                ])
            image = placed.composited(over: image)
        }

        return image.cropped(to: bounds)
    }

    /// A top-left-origin rect in a render of this height, in Core Image's bottom-left space.
    static func ciRect(_ rect: CGRect, renderHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: renderHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
