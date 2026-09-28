//
//  ImitationReelRenderer.swift
//  ReverseSinging
//
//  The shareable video of one impression: the sound, the attempt, the verdict
//

import AVFoundation
import DubAudio
import DubScoring
import VideoToolbox
#if canImport(UIKit)
import UIKit
#else
import AppKit

// The frames are drawn with the UIKit names; on the Mac they are the AppKit classes that do the
// same job, and the context is pushed flipped so text and images land the same way up.
private typealias UIColor = NSColor
private typealias UIFont = NSFont
private typealias UIImage = NSImage
private typealias UIBezierPath = NSBezierPath

private extension NSBezierPath {
    nonisolated convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        self.init(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    }
}

private extension NSImage {
    nonisolated convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }
}

nonisolated private func UIGraphicsPushContext(_ context: CGContext) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
}

nonisolated private func UIGraphicsPopContext() {
    NSGraphicsContext.restoreGraphicsState()
}

nonisolated private func UIGraphicsGetCurrentContext() -> CGContext? {
    NSGraphicsContext.current?.cgContext
}
#endif

/// Everything one imitation video is made from.
nonisolated struct ImitationReel: Sendable {
    let soundName: String
    let emoji: String
    let referenceURL: URL
    let takeURL: URL
    /// The front-camera clip of the attempt, when Booth Cam was on.
    let boothURL: URL?
    let score: ImitationScore
    let verdict: ImitationVerdict
    /// Seeds the confetti, so the video throws the burst the result screen did.
    let seed: UInt64
    var artworkName: String? = nil
}

nonisolated enum ImitationReelError: Error {
    case setupFailed
    case writerFailed((any Error)?)
    case exportFailed((any Error)?)
}

/// Renders an `ImitationReel` into a vertical MP4.
///
/// **Every frame is drawn with Core Graphics straight into the encoder's pixel buffers.** No
/// `AVVideoCompositionCoreAnimationTool`: Core Animation overlays allocate a surface per layer
/// per frame, and on the dub export that crashed whenever the allocation failed (always, on
/// the Simulator). Drawing it ourselves also means stamps and confetti are the same pixels in
/// a frame grab as on a phone.
///
/// Four acts, laid out by `ImitationReelTimeline`: an intro card, the original with its
/// waveform, the attempt (booth footage when there is some, the take's waveform when not),
/// and the reveal: the score counting up, the stamp slamming down, confetti for a pass.
nonisolated enum ImitationReelRenderer {

    static let size = CGSize(width: 1080, height: 1920)
    static let frameRate: Int32 = 30

    /// Renders the reel and returns the finished file in `imitateExportsDirectory`.
    ///
    /// `progress` runs 0...1 on an arbitrary thread.
    @concurrent
    static func render(
        _ reel: ImitationReel,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let referenceDuration = try duration(of: reel.referenceURL)
        let takeDuration = try duration(of: reel.takeURL)
        let timeline = ImitationReelTimeline(referenceDuration: referenceDuration, takeDuration: takeDuration)

        let referenceBars = await WaveformSampler.shared.samples(from: reel.referenceURL, buckets: 44)
        let takeBars = await WaveformSampler.shared.samples(from: reel.takeURL, buckets: 44)

        let scratch = FileManager.default.temporaryDirectory
        let audioURL = scratch.appendingPathComponent("imitate-reel-\(UUID().uuidString).m4a")
        let videoURL = scratch.appendingPathComponent("imitate-reel-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: audioURL)
            try? FileManager.default.removeItem(at: videoURL)
        }

        try ImitationReelAudio.render(
            referenceURL: reel.referenceURL,
            takeURL: reel.takeURL,
            timeline: timeline,
            celebrates: reel.verdict.celebrates,
            to: audioURL
        )
        progress(0.05)

        let painter = ReelPainter(
            reel: reel,
            timeline: timeline,
            referenceBars: referenceBars,
            takeBars: takeBars
        )
        try await writeVideo(painter: painter, boothURL: reel.boothURL, timeline: timeline, to: videoURL) { value in
            progress(0.05 + value * 0.9)
        }

        let destination = AudioFileManager.shared.imitateExportsDirectory()
            .appendingPathComponent(exportFilename(for: reel.soundName))
        try await mux(videoURL: videoURL, audioURL: audioURL, to: destination)
        progress(1)
        return destination
    }

    // MARK: - Video

    private static func writeVideo(
        painter: ReelPainter,
        boothURL: URL?,
        timeline: ImitationReelTimeline,
        to url: URL,
        progress: (Double) -> Void
    ) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let width = Int(size.width), height = Int(size.height)

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                // About 0.12 bits per pixel per frame, as the dub export settled on.
                AVVideoAverageBitRateKey: Int(Double(width * height) * Double(frameRate) * 0.12),
                AVVideoMaxKeyFrameIntervalKey: Int(frameRate) * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ])
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        guard writer.canAdd(input) else { throw ImitationReelError.setupFailed }
        writer.add(input)
        guard writer.startWriting() else { throw ImitationReelError.writerFailed(writer.error) }
        writer.startSession(atSourceTime: .zero)

        var booth: BoothFrameSource?
        if let boothURL { booth = try? await BoothFrameSource.open(boothURL) }
        let frameCount = Int((timeline.total * Double(frameRate)).rounded(.up))

        for frame in 0..<frameCount {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }

            guard let pool = adaptor.pixelBufferPool else { throw ImitationReelError.writerFailed(writer.error) }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard let pixelBuffer else { throw ImitationReelError.setupFailed }

            let time = Double(frame) / Double(frameRate)
            let boothFrame: CGImage?
            switch timeline.act(at: time) {
            case .take(let local): boothFrame = booth?.frame(at: local)
            // The reveal plays over the attempt's last frame.
            case .reveal: boothFrame = booth?.lastFrame
            default: boothFrame = nil
            }

            draw(into: pixelBuffer) { context in
                painter.paint(context, at: time, boothFrame: boothFrame)
            }

            guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)) else {
                throw ImitationReelError.writerFailed(writer.error)
            }
            progress(Double(frame + 1) / Double(frameCount))
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ImitationReelError.writerFailed(writer.error) }
    }

    /// Runs `body` with a top-left-origin context over the buffer, pushed as the UIKit context
    /// so `NSAttributedString` and `UIImage` draw the right way up.
    private static func draw(into buffer: CVPixelBuffer, body: (CGContext) -> Void) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        context.translateBy(x: 0, y: CGFloat(CVPixelBufferGetHeight(buffer)))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        body(context)
        UIGraphicsPopContext()
    }

    // MARK: - Mux

    /// The silent picture and the soundtrack, into one file, without re-encoding either.
    private static func mux(videoURL: URL, audioURL: URL, to destination: URL) async throws {
        let composition = AVMutableComposition()
        let video = AVURLAsset(url: videoURL)
        let audio = AVURLAsset(url: audioURL)

        guard let videoTrack = try await video.loadTracks(withMediaType: .video).first,
              let compositionVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw ImitationReelError.setupFailed }
        let videoRange = try await videoTrack.load(.timeRange)
        try compositionVideo.insertTimeRange(videoRange, of: videoTrack, at: .zero)

        if let audioTrack = try await audio.loadTracks(withMediaType: .audio).first,
           let compositionAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let audioRange = try await audioTrack.load(.timeRange)
            let range = CMTimeRange(start: .zero, duration: CMTimeMinimum(audioRange.duration, videoRange.duration))
            try compositionAudio.insertTimeRange(range, of: audioTrack, at: .zero)
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw ImitationReelError.setupFailed
        }
        do {
            try await export.export(to: destination, as: .mp4)
        } catch {
            throw ImitationReelError.exportFailed(error)
        }
    }

    // MARK: - Helpers

    private static func duration(of url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    private static func exportFilename(for soundName: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let slug = soundName.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "Dubloon-\(slug.isEmpty ? "sound" : slug)-\(formatter.string(from: Date())).mp4"
    }
}

// MARK: - Booth Frames

/// Decodes the booth clip in order, handing back whichever frame is on screen at a time.
nonisolated private final class BoothFrameSource {

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private var current: CGImage?
    private var pending: (time: Double, image: CGImage)?
    private var isExhausted = false

    /// The last frame decoded so far. Once the take act is over, that is the clip's last.
    var lastFrame: CGImage? { pending?.image ?? current }

    static func open(_ url: URL) async throws -> BoothFrameSource {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ImitationReelError.setupFailed
        }
        return try BoothFrameSource(asset: asset, track: track)
    }

    private init(asset: AVAsset, track: AVAssetTrack) throws {
        reader = try AVAssetReader(asset: asset)
        output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ImitationReelError.setupFailed }
        reader.add(output)
        guard reader.startReading() else { throw ImitationReelError.setupFailed }
    }

    /// The frame showing `seconds` into the clip. Only ever asked for in increasing order.
    func frame(at seconds: Double) -> CGImage? {
        while !isExhausted {
            if let pending {
                guard pending.time <= seconds else { break }
                current = pending.image
                self.pending = nil
                continue
            }
            guard let sample = output.copyNextSampleBuffer() else {
                isExhausted = true
                break
            }
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            var image: CGImage?
            VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &image)
            guard let image else { continue }
            pending = (CMSampleBufferGetPresentationTimeStamp(sample).seconds, image)
        }
        return current ?? pending?.image
    }
}

// MARK: - Painter

/// Draws one frame of the reel. Pure: given a time, always the same picture.
nonisolated private struct ReelPainter {

    let reel: ImitationReel
    let timeline: ImitationReelTimeline
    let referenceBars: [Float]
    let takeBars: [Float]
    let confetti: ConfettiSimulation
    let artwork: UIImage?
    let microphone = UIImage(named: "microphone")

    init(reel: ImitationReel, timeline: ImitationReelTimeline, referenceBars: [Float], takeBars: [Float]) {
        self.reel = reel
        self.timeline = timeline
        self.referenceBars = referenceBars
        self.takeBars = takeBars
        confetti = ConfettiSimulation(seed: reel.seed)
        artwork = reel.artworkName.flatMap { UIImage(named: $0) }
    }

    private var size: CGSize { ImitationReelRenderer.size }
    private var width: CGFloat { size.width }
    private var height: CGFloat { size.height }

    // Ink, the app's palette as CGColors.
    private static let canvas = UIColor(red: 0.055, green: 0.059, blue: 0.067, alpha: 1)
    private static let panel = UIColor(red: 0.118, green: 0.129, blue: 0.145, alpha: 1)
    private static let textPrimary = UIColor(red: 0.910, green: 0.918, blue: 0.925, alpha: 1)
    private static let textSecondary = UIColor(red: 0.604, green: 0.627, blue: 0.651, alpha: 1)
    private static let record = UIColor(red: 0.898, green: 0.282, blue: 0.302, alpha: 1)
    private static let highlight = UIColor(red: 0.478, green: 0.573, blue: 0.616, alpha: 1)

    func paint(_ context: CGContext, at time: TimeInterval, boothFrame: CGImage?) {
        Self.canvas.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        switch timeline.act(at: time) {
        case .intro(let t): paintIntro(context, t)
        case .reference(let t): paintReference(context, t)
        case .take(let t): paintTake(context, t, boothFrame: boothFrame)
        case .reveal(let t): paintReveal(context, t, boothFrame: boothFrame)
        }
    }

    // MARK: Acts

    private func paintIntro(_ context: CGContext, _ t: TimeInterval) {
        kicker(Strings.Imitate.Reel.challenge, at: 250, alpha: ease(t / 0.3))

        let pop = spring(t / 0.55)
        soundArtwork(size: 380 * pop, centre: CGPoint(x: width / 2, y: height * 0.38))

        text(Strings.Imitate.Reel.canYouSoundLike, size: 58, weight: .semibold,
             color: Self.textSecondary.withAlphaComponent(ease((t - 0.35) / 0.3)),
             centre: CGPoint(x: width / 2, y: height * 0.58))

        let nameIn = ease((t - 0.6) / 0.35)
        text(reel.soundName.uppercased(), size: 132, weight: .black,
             color: Self.textPrimary.withAlphaComponent(nameIn),
             centre: CGPoint(x: width / 2, y: height * 0.66 + (1 - nameIn) * 40))
    }

    private func paintReference(_ context: CGContext, _ t: TimeInterval) {
        chip(Strings.Imitate.Reel.original, color: Self.highlight, at: CGPoint(x: width / 2, y: 250), centred: true)

        let progress = min(1, t / max(timeline.referenceDuration, 0.01))
        let level = CGFloat(bar(referenceBars, at: progress))
        soundArtwork(size: 330 * (1 + level * 0.12), centre: CGPoint(x: width / 2, y: height * 0.38))

        text(reel.soundName.uppercased(), size: 96, weight: .black, color: Self.textPrimary,
             centre: CGPoint(x: width / 2, y: height * 0.56))

        waveform(referenceBars, progress: progress, tint: Self.highlight,
                 in: CGRect(x: 90, y: height * 0.64, width: width - 180, height: 260))
    }

    private func paintTake(_ context: CGContext, _ t: TimeInterval, boothFrame: CGImage?) {
        let progress = min(1, t / max(timeline.takeDuration, 0.01))

        if let boothFrame {
            fill(boothFrame)
            gradient(context, from: 0.62, alpha: 0.85)
            waveform(takeBars, progress: progress, tint: Self.record,
                     in: CGRect(x: 90, y: height - 380, width: width - 180, height: 200))
        } else {
            if let microphone {
                drawArtwork(microphone, size: 300, centre: CGPoint(x: width / 2, y: height * 0.36))
            }
            waveform(takeBars, progress: progress, tint: Self.record,
                     in: CGRect(x: 90, y: height * 0.56, width: width - 180, height: 320))
        }

        chip(Strings.Imitate.Reel.you, color: Self.record, at: CGPoint(x: 70, y: 160), centred: false, dot: true)
        chip(reel.soundName, color: Self.panel, at: CGPoint(x: width - 70, y: 160), centred: false, alignRight: true, icon: artwork)
    }

    private func paintReveal(_ context: CGContext, _ t: TimeInterval, boothFrame: CGImage?) {
        if let boothFrame {
            fill(boothFrame)
            Self.canvas.withAlphaComponent(0.72 * ease(t / 0.4)).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        // The number counts up over the first second, easing into its final value.
        let count = reel.score.overall * Double(easeOut(t / 0.95))
        kicker(Strings.Imitate.Reel.score, at: height * 0.2, alpha: ease(t / 0.25))
        text("\(Int(count.rounded()))", size: 300, weight: .heavy, color: Self.textPrimary,
             centre: CGPoint(x: width / 2, y: height * 0.32), monospaced: true)

        // Parts of the score, once the total has landed.
        let partsIn = ease((t - 1.6) / 0.4)
        if partsIn > 0 {
            var parts = ["\(Strings.Imitate.Part.rhythm) \(Int(reel.score.rhythm.rounded()))"]
            if let pitch = reel.score.pitch { parts.append("\(Strings.Imitate.Part.pitch) \(Int(pitch.rounded()))") }
            parts.append("\(Strings.Imitate.Part.tone) \(Int(reel.score.tone.rounded()))")
            text(parts.joined(separator: "  ·  "), size: 42, weight: .semibold,
                 color: Self.textSecondary.withAlphaComponent(partsIn),
                 centre: CGPoint(x: width / 2, y: height * 0.64))
        }

        stamp(context, t - ImitationReelTimeline.stampDelay)

        if reel.verdict.celebrates {
            let pieces = confetti.pieces(
                at: t - ImitationReelTimeline.stampDelay,
                in: size,
                from: CGPoint(x: width / 2, y: height * 0.5)
            )
            for piece in pieces { draw(piece, in: context) }
        }

        // Sign-off.
        let outro = ease((t - 2.4) / 0.4)
        if outro > 0 {
            text(Strings.Imitate.Reel.beatMyScore, size: 50, weight: .semibold,
                 color: Self.textPrimary.withAlphaComponent(outro),
                 centre: CGPoint(x: width / 2, y: height * 0.8))
            text("Dubloon", size: 64, weight: .black,
                 color: Self.textSecondary.withAlphaComponent(outro),
                 centre: CGPoint(x: width / 2, y: height * 0.87))
        }
    }

    // MARK: Stamp

    /// Drops from three times its size to its own in 0.16 s, shakes, and stays, rotated like
    /// something slammed on a desk.
    private func stamp(_ context: CGContext, _ t: TimeInterval) {
        guard t >= 0 else { return }

        let landing = 0.16
        let scale: CGFloat = t < landing ? 3 - 2 * CGFloat(easeIn(t / landing)) : 1
        let shake: CGFloat = (t >= landing && t < landing + 0.2)
            ? sin(CGFloat(t - landing) * 90) * 14 * CGFloat(1 - (t - landing) / 0.2)
            : 0
        let alpha = CGFloat(min(1, t / 0.08))

        #if canImport(UIKit)
        let color = UIColor(cgColor: reel.verdict.tint.cgColor)
        #else
        let color = UIColor(cgColor: reel.verdict.tint.cgColor) ?? .white
        #endif
        let font = UIFont.systemFont(ofSize: 124, weight: .black)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color.withAlphaComponent(alpha), .kern: 6]
        let word = NSAttributedString(string: reel.verdict.word, attributes: attributes)
        var textSize = word.size()
        // A long word in a long language is shrunk to fit rather than cropped.
        let maxWidth = width * 0.78
        let fit = textSize.width > maxWidth ? maxWidth / textSize.width : 1
        textSize = CGSize(width: textSize.width * fit, height: textSize.height * fit)

        context.saveGState()
        context.translateBy(x: width / 2 + shake, y: height * 0.5)
        context.rotate(by: -12 * .pi / 180)
        context.scaleBy(x: scale * fit, y: scale * fit)

        let box = CGRect(
            x: -textSize.width / fit / 2 - 44, y: -textSize.height / fit / 2 - 22,
            width: textSize.width / fit + 88, height: textSize.height / fit + 44
        )
        let path = UIBezierPath(roundedRect: box, cornerRadius: 26)
        path.lineWidth = 14
        color.withAlphaComponent(alpha).setStroke()
        path.stroke()
        let inner = UIBezierPath(roundedRect: box.insetBy(dx: 16, dy: 16), cornerRadius: 16)
        inner.lineWidth = 4
        color.withAlphaComponent(alpha * 0.7).setStroke()
        inner.stroke()

        word.draw(at: CGPoint(x: -textSize.width / fit / 2, y: -textSize.height / fit / 2))
        context.restoreGState()
    }

    private func draw(_ piece: ConfettiSimulation.Piece, in context: CGContext) {
        let rgb = ConfettiSimulation.palette[piece.colorIndex]
        context.saveGState()
        context.translateBy(x: piece.position.x, y: piece.position.y)
        context.rotate(by: piece.rotation)
        context.setFillColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: piece.opacity)
        let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2, width: piece.size.width, height: piece.size.height)
        if piece.isRound {
            context.fillEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.width))
        } else {
            context.fill(rect)
        }
        context.restoreGState()
    }

    // MARK: Pieces

    private func fill(_ image: CGImage) {
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = max(width / imageSize.width, height / imageSize.height)
        let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        UIImage(cgImage: image).draw(in: CGRect(
            x: (width - drawn.width) / 2, y: (height - drawn.height) / 2,
            width: drawn.width, height: drawn.height
        ))
    }

    /// Darkens the frame from `from` (a fraction of the height) to the bottom, so the waveform
    /// reads over any face.
    private func gradient(_ context: CGContext, from start: CGFloat, alpha: CGFloat) {
        let colors = [Self.canvas.withAlphaComponent(0).cgColor, Self.canvas.withAlphaComponent(alpha).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height * start), end: CGPoint(x: 0, y: height), options: [.drawsAfterEndLocation])
    }

    private func waveform(_ bars: [Float], progress: Double, tint: UIColor, in rect: CGRect) {
        guard !bars.isEmpty else { return }
        let slot = rect.width / CGFloat(bars.count)
        let barWidth = max(4, slot * 0.6)
        for (index, value) in bars.enumerated() {
            let played = Double(index) / Double(bars.count) <= progress
            let barHeight = max(10, CGFloat(value) * rect.height)
            let x = rect.minX + CGFloat(index) * slot + (slot - barWidth) / 2
            let bar = UIBezierPath(
                roundedRect: CGRect(x: x, y: rect.midY - barHeight / 2, width: barWidth, height: barHeight),
                cornerRadius: barWidth / 2
            )
            (played ? tint : Self.textSecondary.withAlphaComponent(0.35)).setFill()
            bar.fill()
        }
    }

    private func soundArtwork(size: CGFloat, centre: CGPoint) {
        guard let image = artwork ?? microphone else { return }
        drawArtwork(image, size: size, centre: centre)
    }

    private func drawArtwork(_ artwork: UIImage, size: CGFloat, centre: CGPoint) {
        guard size > 1 else { return }
        let scale = size / max(artwork.size.width, artwork.size.height)
        let width = artwork.size.width * scale
        let height = artwork.size.height * scale
        let rect = CGRect(x: centre.x - width / 2, y: centre.y - height / 2,
                          width: width, height: height)
        #if canImport(UIKit)
        artwork.draw(in: rect)
        #else
        artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                     respectFlipped: true, hints: nil)
        #endif
    }

    private func kicker(_ string: String, at y: CGFloat, alpha: CGFloat) {
        text(string.uppercased(), size: 40, weight: .bold, color: Self.textSecondary.withAlphaComponent(alpha),
             centre: CGPoint(x: width / 2, y: y), kern: 8)
    }

    /// A label on a pill, the booth slug's shape at video size.
    private func chip(
        _ string: String, color: UIColor, at point: CGPoint,
        centred: Bool, alignRight: Bool = false, dot: Bool = false, icon: UIImage? = nil
    ) {
        let label = NSAttributedString(string: string.uppercased(), attributes: [
            .font: UIFont.systemFont(ofSize: 38, weight: .bold),
            .foregroundColor: Self.textPrimary,
            .kern: 4
        ])
        let textSize = label.size()
        let dotSpace: CGFloat = dot ? 40 : 0
        let iconSpace: CGFloat = icon == nil ? 0 : 56
        let chipSize = CGSize(width: textSize.width + 56 + dotSpace + iconSpace, height: textSize.height + 28)
        let origin: CGPoint
        if centred {
            origin = CGPoint(x: point.x - chipSize.width / 2, y: point.y - chipSize.height / 2)
        } else if alignRight {
            origin = CGPoint(x: point.x - chipSize.width, y: point.y - chipSize.height / 2)
        } else {
            origin = CGPoint(x: point.x, y: point.y - chipSize.height / 2)
        }
        let rect = CGRect(origin: origin, size: chipSize)
        color.withAlphaComponent(0.9).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: chipSize.height / 2).fill()
        if dot {
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: rect.minX + 30, y: rect.midY - 9, width: 18, height: 18)).fill()
        }
        if let icon {
            drawArtwork(icon, size: 48, centre: CGPoint(x: rect.minX + 52 + dotSpace, y: rect.midY))
        }
        label.draw(at: CGPoint(x: rect.minX + 28 + dotSpace + iconSpace, y: rect.minY + 14))
    }

    private func text(
        _ string: String, size: CGFloat, weight: UIFont.Weight, color: UIColor,
        centre: CGPoint, monospaced: Bool = false, kern: CGFloat = 0
    ) {
        guard color.cgColor.alpha > 0.001 else { return }
        let font = monospaced
            ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
            : UIFont.systemFont(ofSize: size, weight: weight)
        let attributed = NSAttributedString(string: string, attributes: [
            .font: font, .foregroundColor: color, .kern: kern
        ])
        var textSize = attributed.size()
        // Long names in long languages shrink to fit the frame rather than run off it.
        let maxWidth = width - 120
        guard textSize.width > maxWidth else {
            attributed.draw(at: CGPoint(x: centre.x - textSize.width / 2, y: centre.y - textSize.height / 2))
            return
        }
        let context = UIGraphicsGetCurrentContext()
        let fit = maxWidth / textSize.width
        textSize = CGSize(width: textSize.width * fit, height: textSize.height * fit)
        context?.saveGState()
        context?.translateBy(x: centre.x - textSize.width / 2, y: centre.y - textSize.height / 2)
        context?.scaleBy(x: fit, y: fit)
        attributed.draw(at: .zero)
        context?.restoreGState()
    }

    private func bar(_ bars: [Float], at progress: Double) -> Float {
        guard !bars.isEmpty else { return 0 }
        return bars[min(bars.count - 1, Int(progress * Double(bars.count)))]
    }

    // MARK: Easing

    private func ease(_ x: Double) -> CGFloat {
        let t = min(1, max(0, x))
        return CGFloat(t * t * (3 - 2 * t))
    }

    private func easeOut(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return 1 - pow(1 - t, 3)
    }

    private func easeIn(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t * t
    }

    /// Overshoots to about 1.12 and settles, the artwork popping in.
    private func spring(_ x: Double) -> CGFloat {
        let t = min(1, max(0, x))
        return CGFloat(1 - exp(-6 * t) * cos(9 * t))
    }
}
