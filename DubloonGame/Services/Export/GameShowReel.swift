//
//  GameShowReel.swift
//  DubloonGame
//
//  The game's vertical video: the player's booth on top, the show's monitor under it
//

import AVFoundation
import UIKit

/// Lays out and draws the game's 9:16 export, which looks like a moment from the show.
///
/// The Booth Cam footage fills the top of the frame. Under it, on the stage, sits the show's
/// monitor. Its header carries the character's name, the Dubloon wordmark and which line it is.
/// The film plays inside the monitor. Under that come the line being dubbed, on an ivory card,
/// and the original against the player's take as two waveforms with a playhead. Where a line
/// in a booth video has no footage, the top of the frame shows the wordmark on the stage instead
/// of black. A video with no booth footage at all has no top band: the monitor and everything
/// under it sit in the middle of the frame, under a smaller wordmark.
///
/// **Everything but the two films is one track.** The stage, the monitor, the card and the
/// waveforms are drawn into a full-canvas video, laid behind the film and the booth. That is the
/// same trick as the studio's waveform strip (see `DubWaveOverlay`), and for the same reason:
/// Core Animation overlays trap when the offline renderer can't get an IOSurface. The film and
/// the booth are cropped into their rects by the composer, so neither spills over the drawing.
nonisolated enum GameShowReel {

    // MARK: - Layout

    /// The frame, top-left origin, the video composition's own space.
    static let canvas = CGSize(width: 1080, height: 1920)
    /// Where the booth footage plays, when there is any.
    static let boothRect = CGRect(x: 0, y: 0, width: 1080, height: 840)

    /// Where everything on the stage goes. With the booth, the stage block hangs under the
    /// booth's band; without it, the same block moves up into the middle of the frame, with
    /// the wordmark above it.
    struct Layout: Sendable {
        let withBooth: Bool

        /// How far the stage block moves up without the booth: centring the wordmark, its gap
        /// and the block (862...1880) in the frame.
        private var lift: CGFloat { withBooth ? 0 : 862 - (canvas.height - (Self.logoHeight + 44 + 1018)) / 2 - Self.logoHeight - 44 }
        static let logoHeight: CGFloat = 112

        private func place(_ rect: CGRect) -> CGRect { rect.offsetBy(dx: 0, dy: -lift) }

        /// Where the film plays, inside the monitor.
        var film: CGRect { place(CGRect(x: 60, y: 952, width: 960, height: 540)) }
        var monitor: CGRect { place(CGRect(x: 36, y: 862, width: 1008, height: 652)) }
        var header: CGRect { place(CGRect(x: 60, y: 870, width: 960, height: 82)) }
        var quote: CGRect { place(CGRect(x: 66, y: 1540, width: 948, height: 164)) }
        var wave: CGRect { place(CGRect(x: 48, y: 1734, width: 984, height: 138)) }
        /// The waveforms' area inside their panel.
        var field: CGRect { place(CGRect(x: 76, y: 1792, width: 928, height: 66)) }
        /// The wordmark over the monitor, without the booth.
        var logo: CGRect { CGRect(x: 0, y: monitor.minY - 44 - Self.logoHeight, width: canvas.width, height: Self.logoHeight) }
    }

    /// Whether a video gets the booth's band: some line in the cut has footage. Asked by both
    /// the stage render and the composer, so the film lands in the monitor the stage drew.
    static func hasBooth(pack: DubPack, segments: [DubExportSegment], clips: [String: URL], includesBooth: Bool) -> Bool {
        guard includesBooth else { return false }
        return pack.lines.contains { line in
            clips[line.slug] != nil && segments.contains { line.startTime < $0.end && line.endTime > $0.start }
        }
    }

    /// Where `source` has to be cropped and moved so it fills `rect` exactly.
    ///
    /// The crop takes the rect's aspect from the source's middle, or for a portrait source from
    /// `verticalBias` of the way down, so a face filmed at arm's length stays in the band.
    static func fill(
        source: CGSize,
        into rect: CGRect,
        verticalBias: CGFloat = 0.5
    ) -> (crop: CGRect, transform: CGAffineTransform) {
        guard source.width > 0, source.height > 0, rect.width > 0, rect.height > 0 else {
            return (CGRect(origin: .zero, size: source), .identity)
        }
        let aspect = rect.width / rect.height
        let crop: CGRect
        if source.width / source.height > aspect {
            let width = source.height * aspect
            crop = CGRect(x: (source.width - width) / 2, y: 0, width: width, height: source.height)
        } else {
            let height = source.width / aspect
            crop = CGRect(x: 0, y: (source.height - height) * verticalBias, width: source.width, height: height)
        }
        let scale = rect.width / crop.width
        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: rect.minX - crop.minX * scale,
                                             y: rect.minY - crop.minY * scale))
        return (crop, transform)
    }

    // MARK: - Palette

    private enum Ink {
        static let navy = UIColor(red: 0.047, green: 0.133, blue: 0.200, alpha: 1)
        static let ivory = UIColor(red: 0.984, green: 0.965, blue: 0.918, alpha: 1)
        static let cyan = UIColor(red: 0.373, green: 0.827, blue: 0.953, alpha: 1)
        static let coral = UIColor(red: 0.910, green: 0.345, blue: 0.290, alpha: 1)
        static let petrol = UIColor(red: 0.106, green: 0.494, blue: 0.612, alpha: 1)
        static let panel = UIColor(red: 0.031, green: 0.090, blue: 0.141, alpha: 0.94)
    }

    // MARK: - Timeline

    /// One line's stretch of the export, in output time.
    private struct Beat {
        let start: TimeInterval
        let end: TimeInterval
        let line: DubLine
        let number: Int
    }

    /// Where each line falls in the export, walking the cut the way `DubWaveOverlay.bars` does.
    private static func beats(pack: DubPack, segments: [DubExportSegment]) -> [Beat] {
        var beats: [Beat] = []
        var outputStart: TimeInterval = 0
        for segment in segments {
            for (index, line) in pack.lines.enumerated() {
                let overlapStart = max(line.startTime, segment.start)
                let overlapEnd = min(line.endTime, segment.end)
                guard overlapEnd > overlapStart else { continue }
                beats.append(Beat(
                    start: outputStart + overlapStart - segment.start,
                    end: outputStart + overlapEnd - segment.start,
                    line: line,
                    number: index + 1
                ))
            }
            outputStart += segment.duration
        }
        return beats.sorted { $0.start < $1.start }
    }

    /// The line the monitor shows at `time`: the one playing, else the next one coming, else
    /// the last one heard.
    private static func beat(at time: TimeInterval, in beats: [Beat]) -> Beat? {
        beats.first { time >= $0.start && time < $0.end }
            ?? beats.first { $0.start > time }
            ?? beats.last
    }

    // MARK: - Rendering

    private static let frameRate: Int32 = 15

    /// Writes the stage track: the whole canvas, `duration` long, silent.
    static func render(
        pack: DubPack,
        segments: [DubExportSegment],
        bars: DubWaveOverlay.Bars,
        withBooth: Bool,
        duration: TimeInterval,
        to url: URL
    ) async throws {
        let layout = Layout(withBooth: withBooth)
        let beats = beats(pack: pack, segments: segments)
        let backdrop = try drawBackdrop(layout)
        let width = Int(canvas.width), height = Int(canvas.height)

        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,
                AVVideoMaxKeyFrameIntervalKey: Int(frameRate) * 2,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw DubExportError.writerFailed(nil) }
        writer.add(input)
        guard writer.startWriting() else { throw DubExportError.writerFailed(writer.error) }
        writer.startSession(atSourceTime: .zero)

        // Drawn once per line rather than once per frame: only the playhead moves within one.
        var page: (number: Int, image: CGImage)?
        // One past the end, so the track covers the whole export.
        let total = max(2, Int((duration * Double(frameRate)).rounded(.up)) + 1)

        for frame in 0..<total {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }

            let time = Double(frame) / Double(frameRate)
            let current = beat(at: time, in: beats)
            let number = current?.number ?? 0
            if page?.number != number {
                page = (number, try drawPage(layout, backdrop: backdrop, beat: current, lineCount: pack.lines.count, bars: bars))
            }
            guard let page,
                  let buffer = frameBuffer(layout, page: page.image, progress: duration > 0 ? time / duration : 0,
                                           pool: adaptor.pixelBufferPool) else { continue }

            if !adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)) {
                throw DubExportError.writerFailed(writer.error)
            }
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in writer.finishWriting { continuation.resume() } }
        guard writer.status == .completed else { throw DubExportError.writerFailed(writer.error) }
    }

    /// One frame: the line's page, with everything already heard dimmed back and the playhead.
    private static func frameBuffer(_ layout: Layout, page: CGImage, progress: Double, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        } else {
            CVPixelBufferCreate(kCFAllocatorDefault, Int(canvas.width), Int(canvas.height),
                                kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        }
        guard let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        context.draw(page, in: CGRect(origin: .zero, size: canvas))

        // From here on, the same top-left space as the layout.
        context.translateBy(x: 0, y: canvas.height)
        context.scaleBy(x: 1, y: -1)

        let field = layout.field
        let x = field.minX + field.width * CGFloat(min(max(progress, 0), 1))
        context.setFillColor(Ink.navy.withAlphaComponent(0.55).cgColor)
        context.fill(CGRect(x: field.minX, y: field.minY - 4, width: x - field.minX, height: field.height + 8))
        context.setFillColor(Ink.ivory.cgColor)
        context.addPath(CGPath(roundedRect: CGRect(x: x - 2.5, y: field.minY - 8, width: 5, height: field.height + 16),
                               cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
        context.fillPath()
        return buffer
    }

    // MARK: - Drawing

    /// Runs `body` with UIKit drawing into a fresh canvas-sized bitmap, top-left origin.
    private static func draw(_ body: (CGContext) -> Void) throws -> CGImage {
        guard let context = CGContext(
            data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { throw DubExportError.renderSetupFailed }
        context.translateBy(x: 0, y: canvas.height)
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        body(context)
        UIGraphicsPopContext()
        guard let image = context.makeImage() else { throw DubExportError.renderSetupFailed }
        return image
    }

    /// What every page shares: the stage, the wordmark in the booth's band, and the empty
    /// monitor and panels.
    private static func drawBackdrop(_ layout: Layout) throws -> CGImage {
        try draw { context in
            let full = CGRect(origin: .zero, size: canvas)
            Ink.navy.setFill()
            context.fill(full)
            if let stage = UIImage(named: "game-stage") {
                stage.draw(in: aspectFill(stage.size, into: full))
            }
            Ink.navy.withAlphaComponent(0.35).setFill()
            context.fill(full)

            if layout.withBooth {
                // Seen only on a line with no booth footage: the wordmark, centre stage.
                Ink.navy.withAlphaComponent(0.35).setFill()
                context.fill(boothRect)
                drawLogo(height: 150, centredIn: boothRect)

                // The seam between the booth and the stage.
                Ink.navy.setFill()
                context.fill(CGRect(x: 0, y: boothRect.maxY, width: canvas.width, height: 8))
                Ink.cyan.setFill()
                context.fill(CGRect(x: 0, y: boothRect.maxY + 8, width: canvas.width, height: 4))
            } else {
                drawLogo(height: Layout.logoHeight, centredIn: layout.logo)
            }

            let monitorRect = layout.monitor, filmRect = layout.film
            let quoteRect = layout.quote, waveRect = layout.wave

            // The monitor: a navy bezel with a cyan rim, and a black screen behind the film.
            let monitor = UIBezierPath(roundedRect: monitorRect, cornerRadius: 40)
            Ink.navy.setFill()
            UIBezierPath(roundedRect: monitorRect.offsetBy(dx: 0, dy: 8), cornerRadius: 40).fill()
            monitor.fill()
            Ink.cyan.setStroke()
            let rim = UIBezierPath(roundedRect: monitorRect.insetBy(dx: 7, dy: 7), cornerRadius: 33)
            rim.lineWidth = 5
            rim.stroke()
            UIColor.black.setFill()
            context.fill(filmRect)

            // The card the line goes on.
            Ink.navy.setFill()
            UIBezierPath(roundedRect: quoteRect.offsetBy(dx: 0, dy: 9), cornerRadius: 34).fill()
            Ink.ivory.setFill()
            let card = UIBezierPath(roundedRect: quoteRect, cornerRadius: 34)
            card.fill()
            Ink.navy.setStroke()
            card.lineWidth = 6
            card.stroke()

            // The waveform panel.
            Ink.navy.setFill()
            UIBezierPath(roundedRect: waveRect.offsetBy(dx: 0, dy: 8), cornerRadius: 30).fill()
            Ink.panel.setFill()
            let panel = UIBezierPath(roundedRect: waveRect, cornerRadius: 30)
            panel.fill()
            Ink.cyan.withAlphaComponent(0.8).setStroke()
            panel.lineWidth = 4
            panel.stroke()
            let labels = NSMutableAttributedString(
                string: Strings.Dub.original.uppercased(),
                attributes: [.font: GameFont.display(size: 30), .foregroundColor: Ink.cyan]
            )
            labels.append(NSAttributedString(string: "   "))
            labels.append(NSAttributedString(
                string: Strings.RecordingType.attempt.uppercased(),
                attributes: [.font: GameFont.display(size: 30), .foregroundColor: Ink.coral]
            ))
            labels.draw(at: CGPoint(x: waveRect.minX + 28, y: waveRect.minY + 14))
        }
    }

    /// The wordmark, `height` tall, centred in `rect`.
    private static func drawLogo(height: CGFloat, centredIn rect: CGRect) {
        guard let logo = UIImage(named: "game-logo") else { return }
        let width = height * logo.size.width / logo.size.height
        logo.draw(in: CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height))
    }

    /// A line's page: the backdrop with its name, number, caption and the waveforms.
    private static func drawPage(_ layout: Layout, backdrop: CGImage, beat: Beat?, lineCount: Int, bars: DubWaveOverlay.Bars) throws -> CGImage {
        try draw { context in
            // The backdrop is drawn in the flipped space, so it goes in flipped back.
            context.saveGState()
            context.translateBy(x: 0, y: canvas.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(backdrop, in: CGRect(origin: .zero, size: canvas))
            context.restoreGState()

            // In the monitor's header too, unless it is already over the monitor.
            if layout.withBooth {
                drawLogo(height: 70, centredIn: layout.header)
            }

            if let beat {
                drawName(beat.line.character, in: layout.header)
                drawCounter(GameStrings.Dub.lineOf(beat.number, lineCount), in: layout.header)
                drawQuote(beat.line.caption, on: layout.quote)
            }
            drawWaves(bars, in: layout.field)
        }
    }

    /// The character, on a petrol tag at the header's left.
    private static func drawName(_ name: String, in headerRect: CGRect) {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !text.isEmpty else { return }
        let string = fitted(text, size: 38, maxWidth: 300)
        let size = string.size()
        let tag = CGRect(x: headerRect.minX, y: headerRect.midY - 30, width: size.width + 44, height: 60)
        Ink.petrol.setFill()
        let path = UIBezierPath(roundedRect: tag, cornerRadius: 30)
        path.fill()
        Ink.navy.setStroke()
        path.lineWidth = 4
        path.stroke()
        string.draw(at: CGPoint(x: tag.minX + 22, y: tag.midY - size.height / 2))
    }

    /// "Line 3 of 4", at the header's right.
    private static func drawCounter(_ counter: String, in headerRect: CGRect) {
        let string = fitted(counter.uppercased(), size: 34, maxWidth: 290)
        let size = string.size()
        string.draw(at: CGPoint(x: headerRect.maxX - size.width - 6, y: headerRect.midY - size.height / 2))
    }

    /// The display face in ivory, shrunk until it fits `maxWidth`.
    private static func fitted(_ text: String, size: CGFloat, maxWidth: CGFloat) -> NSAttributedString {
        var points = size
        while true {
            let string = NSAttributedString(string: text, attributes: [
                .font: GameFont.display(size: points),
                .foregroundColor: Ink.ivory,
            ])
            if string.size().width <= maxWidth || points <= size * 0.55 { return string }
            points -= 2
        }
    }

    /// The line, in quotes, centred on the card and shrunk until it fits.
    private static func drawQuote(_ caption: String, on quoteRect: CGRect) {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let quoted = "\u{201C}\(text)\u{201D}"
        let box = quoteRect.insetBy(dx: 40, dy: 20)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        var points: CGFloat = 46
        var string = NSAttributedString()
        var bounds = CGRect.zero
        repeat {
            let base = UIFont.systemFont(ofSize: points, weight: .bold)
            let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: points) } ?? base
            string = NSAttributedString(string: quoted, attributes: [
                .font: font, .foregroundColor: Ink.navy, .paragraphStyle: paragraph,
            ])
            bounds = string.boundingRect(with: CGSize(width: box.width, height: .greatestFiniteMagnitude),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            points -= 2
        } while bounds.height > box.height && points > 22

        let rect = CGRect(x: box.minX, y: box.midY - min(bounds.height, box.height) / 2,
                          width: box.width, height: min(bounds.height, box.height) + 2)
        string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
                    context: nil)
    }

    /// The original in cyan and the take in coral, one pair of bars per slot about the middle.
    private static func drawWaves(_ bars: DubWaveOverlay.Bars, in field: CGRect) {
        let count = max(bars.reference.count, bars.take.count)
        guard count > 0 else { return }
        let slot = field.width / CGFloat(count)
        let reach = field.height / 2

        func bar(_ value: Float, index: Int, width: CGFloat, colour: UIColor) {
            let height = max(4, CGFloat(min(max(value, 0), 1)) * reach * 2)
            let x = field.minX + CGFloat(index) * slot + (slot - width) / 2
            colour.setFill()
            UIBezierPath(roundedRect: CGRect(x: x, y: field.midY - height / 2, width: width, height: height),
                         cornerRadius: width / 2).fill()
        }

        for index in 0..<count {
            let reference = index < bars.reference.count ? bars.reference[index] : 0
            let take = index < bars.take.count ? bars.take[index] : 0
            bar(reference, index: index, width: max(2, slot - 1.5), colour: Ink.cyan.withAlphaComponent(0.85))
            if take > 0 {
                bar(take, index: index, width: max(1.5, slot * 0.45), colour: Ink.coral)
            }
        }
    }

    private static func aspectFill(_ size: CGSize, into rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: rect.midX - drawn.width / 2, y: rect.midY - drawn.height / 2,
                      width: drawn.width, height: drawn.height)
    }
}
