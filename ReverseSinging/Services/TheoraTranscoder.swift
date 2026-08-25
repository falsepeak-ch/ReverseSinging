//
//  TheoraTranscoder.swift
//  ReverseSinging
//
//  Converts a pack's Ogg Theora scene into H.264, once, at import time
//

import AVFoundation
import CoreVideo
import XiphTheora

/// Turns `dub_video.ogv` into an MP4 AVFoundation can actually play.
///
/// Dub packs ship their scene as Ogg Theora, which no Apple framework decodes. Rather than
/// carry a decoder around at playback time, the file is converted once when the pack is
/// imported and the original is thrown away; every screen downstream then deals in ordinary
/// H.264. Decoding is libtheora, encoding is VideoToolbox through `AVAssetWriter`.
nonisolated enum TheoraTranscoder {

    enum TranscodeError: LocalizedError {
        case notTheora
        case badHeaders
        case decoderUnavailable
        case unsupportedPixelFormat
        case writerFailed(Error?)
        case noFrames
        case lengthMismatch(expected: TimeInterval, actual: TimeInterval)

        var errorDescription: String? {
            switch self {
            case .notTheora: return "No Theora video stream in this file"
            case .badHeaders: return "Theora headers are incomplete"
            case .decoderUnavailable: return "Could not start the Theora decoder"
            case .unsupportedPixelFormat: return "Unsupported Theora pixel format"
            case .writerFailed(let error): return "Video writer failed: \(error?.localizedDescription ?? "unknown")"
            case .noFrames: return "No frames could be decoded"
            case .lengthMismatch(let expected, let actual):
                return String(
                    format: "Converted video is %.2fs but should be %.2fs", actual, expected
                )
            }
        }
    }

    /// How much of the file is read at a time when feeding the Ogg demuxer.
    private static let readChunkSize = 64 * 1024

    /// What a finished conversion turned out to be.
    struct Output: Equatable, Sendable {
        /// Frames actually written, including duplicates.
        let frameCount: Int
        /// The file's length, from the last frame's index rather than measured back off disk.
        let duration: TimeInterval
    }

    // MARK: - Entry Point

    /// Decodes `source` and writes an H.264 MP4 to `destination`.
    ///
    /// Blocking and CPU-bound — call it off the main actor. `progress` reports 0...1 by how
    /// much of the source has been consumed, because a feature-length scene takes minutes and
    /// a silent bar reads as a hang.
    ///
    /// Returns what was written, so the caller can check the result against the source instead
    /// of assuming it came out the right length.
    @discardableResult
    static func transcode(
        ogv source: URL,
        to destination: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws -> Output {
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }

        let totalBytes = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 0
        var bytesRead = 0
        // A 150 MB scene is ~2,400 chunks; reporting every one of them would hop to the
        // main actor far more often than a progress bar can show.
        var lastReported = 0.0

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        var sync = ogg_sync_state()
        ogg_sync_init(&sync)
        defer { ogg_sync_clear(&sync) }

        var stream = ogg_stream_state()
        var streamInitialised = false
        defer { if streamInitialised { ogg_stream_clear(&stream) } }

        var info = th_info()
        th_info_init(&info)
        defer { th_info_clear(&info) }

        var comment = th_comment()
        th_comment_init(&comment)
        defer { th_comment_clear(&comment) }

        var setup: OpaquePointer? = nil
        defer { if setup != nil { th_setup_free(setup) } }

        var decoder: OpaquePointer? = nil
        defer { if decoder != nil { th_decode_free(decoder) } }

        var writer: Writer? = nil
        var headersRemaining = true
        var foundTheora = false
        /// Where the next frame goes when the stream gives no granule position to read it from.
        var nextFrameIndex: Int64 = 0
        var framesWritten = 0

        // MARK: Demux + decode

        readLoop: while true {
            var page = ogg_page()

            // Drain every page currently buffered before reading more of the file.
            //
            // `-1` is a hole in the stream, not the end of the buffered data — stopping on it
            // would leave whole pages unread behind the damage.
            while true {
                let pageStatus = ogg_sync_pageout(&sync, &page)
                if pageStatus == 0 { break }
                if pageStatus < 0 { continue }

                let serial = ogg_page_serialno(&page)

                if ogg_page_bos(&page) != 0, !foundTheora {
                    if streamInitialised { ogg_stream_clear(&stream) }
                    ogg_stream_init(&stream, serial)
                    streamInitialised = true
                } else if !streamInitialised || serial != stream.serialno {
                    // A pack's Ogg container also carries a Vorbis track; skip anything
                    // that isn't the stream we locked onto.
                    continue
                }

                guard ogg_stream_pagein(&stream, &page) == 0 else { continue }

                var packet = ogg_packet()
                while ogg_stream_packetout(&stream, &packet) == 1 {
                    if headersRemaining {
                        let status = th_decode_headerin(&info, &comment, &setup, &packet)

                        if status < 0 {
                            // Not Theora — this was some other bos stream, keep looking.
                            if !foundTheora {
                                ogg_stream_clear(&stream)
                                streamInitialised = false
                                break
                            }
                            throw TranscodeError.badHeaders
                        }

                        foundTheora = true

                        if status == 0 {
                            // Headers done; this packet is the first frame.
                            headersRemaining = false
                            guard let context = th_decode_alloc(&info, setup) else {
                                throw TranscodeError.decoderUnavailable
                            }
                            decoder = context
                            writer = try Writer(destination: destination, info: info)
                        } else {
                            continue
                        }
                    }

                    guard let decoder, let writer else { continue }

                    var granulePosition: ogg_int64_t = 0
                    let status = th_decode_packetin(decoder, &packet, &granulePosition)

                    // `TH_DUPFRAME` is not a failure. It means the packet is a duplicate —
                    // a 0-byte frame, or an inter frame with no coded blocks — so the
                    // decoder's picture is unchanged. libtheora's *player* example skips the
                    // redraw on it, because the frame it wants is already on screen. A
                    // transcoder is the other case: the frame still owns its slot on the
                    // timeline, so it has to be written out again. Dropping it shortens the
                    // file and pulls everything after it earlier, by a frame every time.
                    guard status == 0 || status == TH_DUPFRAME else { continue }

                    // The granule position carries the frame's own absolute index, so it —
                    // not a running counter — is what the timeline is built from. A packet
                    // that fails to decode then leaves the previous frame held for a beat
                    // longer, rather than shifting the whole rest of the scene.
                    //
                    // Floored at the running counter for two reasons: presentation times
                    // handed to `AVAssetWriter` must strictly increase, and a stream can
                    // report no granule position at all (`-1`) on the frames before the
                    // first page boundary.
                    var frameIndex = granulePosition >= 0
                        ? th_granule_frame(UnsafeMutableRawPointer(decoder), granulePosition)
                        : -1
                    frameIndex = max(frameIndex, nextFrameIndex)
                    nextFrameIndex = frameIndex + 1

                    // th_ycbcr_buffer is a C array of three planes; an array gives Swift
                    // the contiguous buffer the call expects. Still valid after a duplicate:
                    // the call hands back the picture already in the frame buffer.
                    var planes = [th_img_plane](
                        repeating: th_img_plane(width: 0, height: 0, stride: 0, data: nil),
                        count: 3
                    )
                    guard th_decode_ycbcr_out(decoder, &planes) == 0 else { continue }

                    try writer.append(planes: planes, info: info, at: frameIndex)
                    framesWritten += 1
                }
            }

            let chunk = handle.readData(ofLength: readChunkSize)
            if chunk.isEmpty { break readLoop }

            bytesRead += chunk.count
            if totalBytes > 0 {
                let fraction = min(1, Double(bytesRead) / Double(totalBytes))
                if fraction - lastReported >= 0.005 {
                    lastReported = fraction
                    progress?(fraction)
                }
            }

            chunk.withUnsafeBytes { raw in
                guard let base = raw.baseAddress,
                      let target = ogg_sync_buffer(&sync, chunk.count) else { return }
                memcpy(target, base, chunk.count)
                ogg_sync_wrote(&sync, chunk.count)
            }
        }

        guard foundTheora else { throw TranscodeError.notTheora }
        guard let writer, framesWritten > 0 else { throw TranscodeError.noFrames }

        let result = try writer.finish()
        progress?(1)
        return result
    }

    // MARK: - Writer

    /// Wraps the `AVAssetWriter` side: sets up H.264 at the video's own size and frame rate,
    /// and converts each decoded Theora frame into a pixel buffer to append.
    private final class Writer {
        private let writer: AVAssetWriter
        private let input: AVAssetWriterInput
        private let adaptor: AVAssetWriterInputPixelBufferAdaptor
        private let timescale: CMTimeScale
        private let frameDuration: CMTimeValue
        private let width: Int
        private let height: Int
        /// Highest index appended so far, which is what sets the file's length.
        private var lastIndex: Int64 = -1
        private var framesAppended = 0

        init(destination: URL, info: th_info) throws {
            // The picture region, not the padded frame: Theora rounds coded dimensions up to
            // a multiple of 16 and the extra rows are not meant to be shown.
            width = Int(info.pic_width)
            height = Int(info.pic_height)

            guard width > 0, height > 0 else { throw TranscodeError.badHeaders }

            // `Int32(_:)` traps rather than throwing, and these are `ogg_uint32_t` straight
            // out of a file that may be anything at all. A malformed header should be a bad
            // import, not a crash.
            guard let fpsNumerator = Int32(exactly: info.fps_numerator), fpsNumerator > 0,
                  let fpsDenominator = Int32(exactly: info.fps_denominator), fpsDenominator > 0
            else { throw TranscodeError.badHeaders }

            timescale = CMTimeScale(fpsNumerator)
            frameDuration = CMTimeValue(fpsDenominator)

            do {
                writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
            } catch {
                throw TranscodeError.writerFailed(error)
            }

            input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: Self.bitRate(
                        width: width, height: height,
                        fps: Double(fpsNumerator) / Double(fpsDenominator)
                    ),
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ],
            ])
            input.expectsMediaDataInRealTime = false

            adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                ]
            )

            writer.add(input)
            guard writer.startWriting() else { throw TranscodeError.writerFailed(writer.error) }
            writer.startSession(atSourceTime: .zero)
        }

        /// Bits per second for the encode.
        ///
        /// Without this AVFoundation picks a very high default: a 158 MB Theora scene came
        /// back out as a 290 MB MP4, which defeats the point of converting at import — the
        /// original was discarded to reclaim that space. Scaled by pixel rate so the figure
        /// holds for any size, and clamped so a tiny clip is not starved nor a large one
        /// allowed to run away.
        private static func bitRate(width: Int, height: Int, fps: Double) -> Int {
            let bitsPerPixel = 0.07
            let rate = Double(width * height) * max(1, fps) * bitsPerPixel
            return Int(min(max(rate, 800_000), 8_000_000))
        }

        func append(planes: [th_img_plane], info: th_info, at index: Int64) throws {
            guard let pool = adaptor.pixelBufferPool else {
                throw TranscodeError.writerFailed(writer.error)
            }

            var pixelBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
                  let buffer = pixelBuffer else {
                throw TranscodeError.writerFailed(writer.error)
            }

            try Self.fill(buffer, from: planes, info: info, width: width, height: height)

            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }

            let time = CMTime(value: frameDuration * index, timescale: timescale)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw TranscodeError.writerFailed(writer.error)
            }

            lastIndex = max(lastIndex, index)
            framesAppended += 1
        }

        func finish() throws -> Output {
            // Without an explicit end the file runs to the last frame's *start* and the final
            // frame's duration is whatever AVFoundation infers. A scene that ends on a held
            // shot — a run of duplicate frames — would come up short by exactly that run.
            let end = CMTime(value: frameDuration * (lastIndex + 1), timescale: timescale)
            writer.endSession(atSourceTime: end)

            input.markAsFinished()

            let done = DispatchSemaphore(value: 0)
            writer.finishWriting { done.signal() }
            done.wait()

            guard writer.status == .completed else {
                throw TranscodeError.writerFailed(writer.error)
            }

            return Output(frameCount: framesAppended, duration: end.seconds)
        }

        // MARK: Pixel conversion

        /// Copies a decoded Theora frame into an NV12 pixel buffer.
        ///
        /// Plane copies only — no colour maths. Theora's Y'CbCr and NV12's are the same
        /// values in a different arrangement, so the work is memcpy for luma and an
        /// interleave for chroma. 4:2:2 and 4:4:4 have their chroma decimated to 4:2:0 on
        /// the way through, which is what the H.264 encoder wants anyway.
        ///
        /// The chroma interleave runs on raw pointers rather than subscripts. A real pack is
        /// 1080p and five minutes long — about seven thousand frames — and at half a million
        /// chroma samples each, bounds-checked indexing turns the conversion into a wait long
        /// enough to look like a hang.
        private static func fill(
            _ buffer: CVPixelBuffer,
            from planes: [th_img_plane],
            info: th_info,
            width: Int,
            height: Int
        ) throws {
            let (chromaX, chromaY): (Int, Int)
            switch info.pixel_fmt {
            case TH_PF_420: (chromaX, chromaY) = (1, 1)
            case TH_PF_422: (chromaX, chromaY) = (1, 0)
            case TH_PF_444: (chromaX, chromaY) = (0, 0)
            default: throw TranscodeError.unsupportedPixelFormat
            }

            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

            guard let lumaBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
                  let chromaBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else {
                throw TranscodeError.unsupportedPixelFormat
            }

            // The visible picture can sit at an offset inside the coded frame.
            let offsetX = Int(info.pic_x)
            let offsetY = Int(info.pic_y)

            let luma = planes[0]
            let cb = planes[1]
            let cr = planes[2]

            guard let lumaSource = luma.data,
                  let cbSource = cb.data,
                  let crSource = cr.data else {
                throw TranscodeError.unsupportedPixelFormat
            }

            // MARK: Luma — a straight row-by-row copy.

            let lumaDestinationStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            let lumaSourceStride = Int(luma.stride)
            let copyWidth = min(width, Int(luma.width) - offsetX)

            for row in 0..<height {
                let sourceRow = lumaSource.advanced(by: (row + offsetY) * lumaSourceStride + offsetX)
                let destinationRow = lumaBase.advanced(by: row * lumaDestinationStride)
                memcpy(destinationRow, sourceRow, copyWidth)
            }

            // MARK: Chroma — interleave Cb and Cr into NV12's single plane.

            let chromaDestinationStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            let chromaHeight = (height + 1) / 2
            let cbStride = Int(cb.stride)
            let crStride = Int(cr.stride)
            // One source sample per output column when the source is already 4:2:0; every
            // second one when it carries full-width chroma.
            let columnStep = 2 >> chromaX
            let chromaOffsetX = offsetX >> chromaX
            let chromaOffsetY = offsetY >> chromaY

            // Never read past the source plane, whatever the picture offset is.
            let availableColumns = (Int(cb.width) - chromaOffsetX) / columnStep
            let chromaWidth = max(0, min((width + 1) / 2, availableColumns))

            let destination = chromaBase.assumingMemoryBound(to: UInt8.self)

            for row in 0..<chromaHeight {
                // Map an NV12 row back to the source plane's row, decimating when the source
                // has more chroma resolution than 4:2:0.
                let sourceRow = ((row * 2) >> chromaY) + chromaOffsetY
                let cbRow = cbSource.advanced(by: sourceRow * cbStride + chromaOffsetX)
                let crRow = crSource.advanced(by: sourceRow * crStride + chromaOffsetX)
                let destinationRow = destination.advanced(by: row * chromaDestinationStride)

                var column = 0
                var source = 0
                while column < chromaWidth {
                    destinationRow[column * 2] = cbRow[source]
                    destinationRow[column * 2 + 1] = crRow[source]
                    column += 1
                    source += columnStep
                }
            }
        }
    }
}
