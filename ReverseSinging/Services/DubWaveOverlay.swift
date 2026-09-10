//
//  DubWaveOverlay.swift
//  ReverseSinging
//
//  The waveform strip along the foot of a vertical export
//

import AVFoundation
import CoreGraphics
import CoreText

/// Draws the line the film says against the line the user said, along the bottom of a
/// vertical export.
///
/// The point is the comparison, not the decoration: the scene's own dialogue is drawn above
/// the centre rule and the take below it, on one shared time axis, so anyone watching the
/// clip can see where the dub landed and where it didn't. That is the same reading the record
/// screen offers while dubbing, carried into the file so it survives being posted.
///
/// **Bars are pre-computed, the playhead is animated.** Everything but the sweep is one
/// static path per waveform, drawn once. `AVVideoCompositionCoreAnimationTool` renders a
/// layer tree per frame, and asking it to lay out several hundred sublayers every frame of a
/// five-minute export is the difference between an export that takes a minute and one that
/// takes ten.
nonisolated enum DubWaveOverlay {

    /// The two waveforms, resampled onto the export's own timeline.
    struct Bars: Equatable, Sendable {
        /// The scene's dialogue, bar by bar, normalised 0...1.
        let reference: [Float]
        /// The user's takes, on the same axis. Zero wherever nothing was recorded.
        let take: [Float]

        var isEmpty: Bool { reference.allSatisfy { $0 == 0 } && take.allSatisfy { $0 == 0 } }
    }

    /// How many bars a strip is drawn from, whatever width it ends up being given.
    ///
    /// Fixed rather than derived from the field, so sampling does not have to know the
    /// geometry: roughly one bar per six pixels at the 1080-wide canvas, which is fine enough
    /// to show syllables and coarse enough that a whole scene is a few hundred rounded rects
    /// rather than a few thousand.
    private static let barCount = 160

    // MARK: - Sampling

    /// Resamples every line's reference and take onto the output timeline of a cut.
    ///
    /// A session reel drops the silence between lines, so scene time and output time are not
    /// the same clock. Each segment is walked in output order and the lines inside it are
    /// placed where they actually end up in the file, which is the only mapping that makes
    /// the strip line up with what is heard.
    static func bars(pack: DubPack, segments: [DubExportSegment]) async -> Bars {
        let count = barCount
        let total = segments.reduce(0) { $0 + $1.duration }

        var reference = [Float](repeating: 0, count: count)
        var take = [Float](repeating: 0, count: count)
        guard total > 0 else { return Bars(reference: reference, take: take) }

        let sampler = WaveformSampler.shared
        var outputStart: TimeInterval = 0

        for segment in segments {
            for line in pack.lines {
                let overlapStart = max(line.startTime, segment.start)
                let overlapEnd = min(line.endTime, segment.end)
                guard overlapEnd > overlapStart else { continue }

                let first = bar(at: outputStart + (overlapStart - segment.start), of: total, count: count)
                let last = bar(at: outputStart + (overlapEnd - segment.start), of: total, count: count)
                let buckets = max(1, last - first)

                // Sampling the whole file into the overlap's worth of bars is exact whenever
                // the overlap is the whole line, which every cut but a scene that ends
                // mid-line produces.
                write(await sampler.samples(from: pack.referenceAudioURL(for: line), buckets: buckets),
                      into: &reference, from: first)

                let takeURL = pack.takeURL(for: line)
                if FileManager.default.fileExists(atPath: takeURL.path) {
                    write(await sampler.samples(from: takeURL, buckets: buckets),
                          into: &take, from: first)
                }
            }
            outputStart += segment.duration
        }

        return Bars(reference: reference, take: take)
    }

    private static func bar(at time: TimeInterval, of total: TimeInterval, count: Int) -> Int {
        let fraction = min(max(time / total, 0), 1)
        return min(count, Int((fraction * Double(count)).rounded()))
    }

    /// Lays one clip's peaks into the strip without disturbing what a neighbouring line put
    /// there. Overlapping lines are legal in a manifest, so the louder of the two wins rather
    /// than the later one.
    private static func write(_ peaks: [Float], into bars: inout [Float], from start: Int) {
        for (offset, peak) in peaks.enumerated() {
            let index = start + offset
            guard index >= 0, index < bars.count else { continue }
            bars[index] = max(bars[index], peak)
        }
    }


    // MARK: - Drawing

    /// Colours lifted from `Colors.swift`. Core Graphics cannot read the SwiftUI palette, and
    /// a strip that drifted from the app's own greys would look like someone else's overlay.
    private enum Ink {
        static let panel = CGColor(srgbRed: 0.086, green: 0.094, blue: 0.106, alpha: 1)
        static let rule = CGColor(srgbRed: 0.180, green: 0.196, blue: 0.216, alpha: 1)
        static let reference = CGColor(srgbRed: 0.604, green: 0.627, blue: 0.651, alpha: 1)
        static let take = CGColor(srgbRed: 0.898, green: 0.282, blue: 0.302, alpha: 0.90)
        static let label = CGColor(srgbRed: 0.420, green: 0.447, blue: 0.471, alpha: 1)
        static let playhead = CGColor(srgbRed: 0.910, green: 0.918, blue: 0.925, alpha: 1)
        /// Wash over the stretch already heard. Alpha, so it dims whatever it covers rather
        /// than needing a second drawing of everything in duller colours.
        static let spent = CGColor(srgbRed: 0.055, green: 0.059, blue: 0.067, alpha: 0.55)
    }

    /// Where things sit inside the strip. Worked out once and shared by the drawing and the
    /// playhead, so the head cannot travel across a different field than the bars were drawn in.
    private struct Metrics {
        let size: CGSize
        /// The waveforms' area, to the right of the names.
        let field: CGRect
        /// The names' column, to the left of it.
        let column: CGRect

        init(size: CGSize) {
            self.size = size
            let inset = (size.height * 0.14).rounded()
            // The names live in their own column rather than over the bars: a label sitting on
            // a waveform is unreadable exactly where the waveform is loudest, which is the
            // part worth looking at.
            let gutter = (size.width * 0.16).rounded()
            field = CGRect(
                x: inset + gutter,
                y: inset,
                width: size.width - inset * 2 - gutter,
                height: size.height - inset * 2
            )
            column = CGRect(x: inset, y: field.minY, width: gutter - inset, height: field.height)
        }
    }

    /// The whole strip, drawn flat.
    ///
    /// **Everything is baked into one image on purpose.** The obvious layer tree — a shape
    /// layer per waveform, a text layer per name — asks Core Animation to rasterise all of it
    /// again for every frame of the export, and the offline renderer takes an IOSurface per
    /// pass to do it. Under load that allocation fails, and it fails by trapping, so the
    /// export does not degrade, it takes the app with it. One decoded image costs one
    /// allocation for the whole render.
    private static func stripImage(
        metrics: Metrics,
        bars: Bars,
        labels: (reference: String, take: String)
    ) -> CGImage? {
        let width = Int(metrics.size.width)
        let height = Int(metrics.size.height)
        guard width > 0, height > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(Ink.panel)
        context.fill(CGRect(x: 0, y: 0, width: metrics.size.width, height: metrics.size.height))

        context.setFillColor(Ink.rule)
        context.fill(CGRect(x: metrics.field.minX, y: metrics.field.midY - 1, width: metrics.field.width, height: 2))

        draw(bars.reference, up: true, in: metrics.field, colour: Ink.reference, into: context)
        draw(bars.take, up: false, in: metrics.field, colour: Ink.take, into: context)

        draw(labels.reference, atTop: true, in: metrics.column, colour: Ink.label, into: context)
        draw(labels.take, atTop: false, in: metrics.column, colour: Ink.label, into: context)

        return context.makeImage()
    }

    /// One waveform, growing from the centre rule.
    private static func draw(
        _ values: [Float],
        up: Bool,
        in field: CGRect,
        colour: CGColor,
        into context: CGContext
    ) {
        guard !values.isEmpty else { return }

        context.setFillColor(colour)

        let slot = field.width / CGFloat(values.count)
        let barWidth = max(1, slot - 2)
        // Half the field each way, less a hair so the two never touch across the rule.
        let reach = field.height / 2 - 3

        for (index, value) in values.enumerated() {
            // A floor, so a silent stretch reads as a rule rather than as a hole in the strip.
            let barHeight = max(2, CGFloat(min(max(value, 0), 1)) * reach)
            let x = field.minX + CGFloat(index) * slot + (slot - barWidth) / 2
            let y = up ? field.midY : field.midY - barHeight

            context.addPath(
                CGPath(
                    roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight),
                    cornerWidth: barWidth / 2,
                    cornerHeight: barWidth / 2,
                    transform: nil
                )
            )
        }

        context.fillPath()
    }

    /// One name, beside the half of the field it belongs to.
    ///
    /// Right-aligned and clipped to its column rather than shrunk to fit: these are two short
    /// words in twenty-one languages, and a name clipped at the edge still says which wave is
    /// which, where a name that ran on would cross into the bars.
    private static func draw(
        _ text: String,
        atTop: Bool,
        in column: CGRect,
        colour: CGColor,
        into context: CGContext
    ) {
        let size = (column.height * 0.14).rounded()
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text.uppercased(),
            // Core Text's own attribute names, not UIKit's: nothing here needs a view layer,
            // and this file is the one part of the app that runs with no UI at all.
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: colour,
                kCTKernAttributeName as NSAttributedString.Key: size * 0.06
            ]
        ))

        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let baseline = atTop
            ? column.midY + column.height / 4 - bounds.height / 2
            : column.midY - column.height / 4 - bounds.height / 2

        context.saveGState()
        context.clip(to: column)
        context.textPosition = CGPoint(x: column.maxX - bounds.width, y: baseline)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    // MARK: - Rendering

    /// Frame rate of the strip clip. The only thing that moves is the playhead, and a sweep
    /// across 1080 pixels advances about four of them per frame at this rate.
    private static let frameRate: Int32 = 15

    /// Writes the strip as its own silent video, for the composition to lay over the picture.
    ///
    /// **Deliberately a video track rather than a Core Animation overlay.** The obvious way to
    /// put graphics into an export is `AVVideoCompositionCoreAnimationTool`, and the offline
    /// Core Animation renderer behind it takes an IOSurface per layer per frame. When one of
    /// those allocations fails it traps rather than returning nil, so the export does not lose
    /// its overlay, it takes the app down — and on the Simulator it does this every time. A
    /// track goes through the same compositor as the scene and the booth, is positioned by the
    /// same layout arithmetic, and shows up in a frame grab, which is also what makes it
    /// testable.
    static func renderStrip(
        bars: Bars,
        labels: (reference: String, take: String),
        size: CGSize,
        duration: TimeInterval,
        to url: URL
    ) async throws {
        let metrics = Metrics(size: size)
        guard let bed = stripImage(metrics: metrics, bars: bars, labels: labels) else {
            throw DubExportError.renderSetupFailed
        }

        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 1_500_000,
                    AVVideoMaxKeyFrameIntervalKey: Int(frameRate) * 2
                ]
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )

        guard writer.canAdd(input) else { throw DubExportError.writerFailed(nil) }
        writer.add(input)
        guard writer.startWriting() else { throw DubExportError.writerFailed(writer.error) }
        writer.startSession(atSourceTime: .zero)

        let total = max(1, Int(duration * Double(frameRate)))

        for frame in 0..<total {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }

            let progress = Double(frame) / Double(total)
            guard let buffer = pixelBuffer(
                bed: bed,
                metrics: metrics,
                progress: progress,
                pool: adaptor.pixelBufferPool
            ) else { continue }

            if !adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)) {
                throw DubExportError.writerFailed(writer.error)
            }
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }

        guard writer.status == .completed else { throw DubExportError.writerFailed(writer.error) }
    }

    /// One frame: the drawn strip, with the playhead at `progress` and everything behind it
    /// lifted to the played colour.
    private static func pixelBuffer(
        bed: CGImage,
        metrics: Metrics,
        progress: Double,
        pool: CVPixelBufferPool?
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        } else {
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(metrics.size.width),
                Int(metrics.size.height),
                kCVPixelFormatType_32ARGB,
                [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary,
                &pixelBuffer
            )
        }

        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(metrics.size.width),
            height: Int(metrics.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        let full = CGRect(origin: .zero, size: metrics.size)
        context.draw(bed, in: full)

        let x = metrics.field.minX + metrics.field.width * CGFloat(min(max(progress, 0), 1))

        // Everything already heard is dimmed back, so the bright part of the strip is the
        // stretch still to come and the join between them is where the take is.
        context.setFillColor(Ink.spent)
        context.fill(CGRect(x: metrics.field.minX, y: 0, width: x - metrics.field.minX, height: metrics.size.height))

        context.setFillColor(Ink.playhead)
        context.fill(CGRect(x: x - 1.5, y: metrics.field.minY, width: 3, height: metrics.field.height))

        return buffer
    }
}
