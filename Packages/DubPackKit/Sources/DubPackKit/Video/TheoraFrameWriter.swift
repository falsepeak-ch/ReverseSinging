//
//  TheoraFrameWriter.swift
//  DubPackKit
//

import AVFoundation
import CoreVideo
import Foundation
import XiphTheora

/// The `AVAssetWriter` half of `TheoraTranscoder`: H.264 at the video's own size and frame
/// rate, fed one decoded Theora frame at a time.
final class TheoraFrameWriter {

    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let timescale: CMTimeScale
    private let frameDuration: CMTimeValue
    private let width: Int
    private let height: Int
    /// Highest frame index appended so far, which is what sets the file's length.
    private var lastIndex: Int64 = -1
    private var framesAppended = 0

    init(destination: URL, info: th_info) throws(VideoConversionFailure) {
        // The picture region, not the padded frame: Theora rounds coded dimensions up to a
        // multiple of 16 and the extra rows are not meant to be seen.
        width = Int(info.pic_width)
        height = Int(info.pic_height)
        guard width > 0, height > 0 else { throw .badHeaders }

        // `Int32(_:)` would trap on these `ogg_uint32_t`s from a file that may be anything;
        // a malformed header is a failed conversion, not a crash.
        guard let fpsNumerator = Int32(exactly: info.fps_numerator), fpsNumerator > 0,
              let fpsDenominator = Int32(exactly: info.fps_denominator), fpsDenominator > 0 else {
            throw .badHeaders
        }
        timescale = CMTimeScale(fpsNumerator)
        frameDuration = CMTimeValue(fpsDenominator)

        do {
            writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        } catch {
            throw .writerFailed(detail: error.localizedDescription)
        }

        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Self.bitRate(
                    width: width,
                    height: height,
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
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            ]
        )

        writer.add(input)
        guard writer.startWriting() else { throw .writerFailed(detail: Self.describe(writer.error)) }
        writer.startSession(atSourceTime: .zero)
    }

    /// Bits per second for the encode.
    ///
    /// Left to itself AVFoundation picks a very high rate: a 158 MB Theora scene came back as a
    /// 290 MB MP4, which defeats converting at install to reclaim the original's space. Scaled
    /// by pixel rate so the figure holds at any size, and clamped at both ends.
    private static func bitRate(width: Int, height: Int, fps: Double) -> Int {
        let bitsPerPixel = 0.07
        let rate = Double(width * height) * max(1, fps) * bitsPerPixel
        return Int(min(max(rate, 800_000), 8_000_000))
    }

    func append(planes: [th_img_plane], info: th_info, at index: Int64) throws(VideoConversionFailure) {
        guard let pool = adaptor.pixelBufferPool else {
            throw .writerFailed(detail: Self.describe(writer.error))
        }

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer else {
            throw .writerFailed(detail: Self.describe(writer.error))
        }

        try Self.fill(buffer, from: planes, info: info, width: width, height: height)

        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.002)
        }

        let time = CMTime(value: frameDuration * index, timescale: timescale)
        guard adaptor.append(buffer, withPresentationTime: time) else {
            throw .writerFailed(detail: Self.describe(writer.error))
        }

        lastIndex = max(lastIndex, index)
        framesAppended += 1
    }

    func finish() throws(VideoConversionFailure) -> TheoraTranscoder.Output {
        // Without an explicit end the file runs to the last frame's *start*, and a scene that
        // ends on a held shot comes up short by exactly that hold.
        let end = CMTime(value: frameDuration * (lastIndex + 1), timescale: timescale)
        writer.endSession(atSourceTime: end)
        input.markAsFinished()

        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()

        guard writer.status == .completed else {
            throw .writerFailed(detail: Self.describe(writer.error))
        }
        return TheoraTranscoder.Output(frameCount: framesAppended, duration: end.seconds)
    }

    private static func describe(_ error: (any Error)?) -> String {
        error?.localizedDescription ?? "unknown"
    }

    // MARK: - Pixel Conversion

    /// Copies a decoded Theora frame into an NV12 pixel buffer.
    ///
    /// Plane copies only, no colour maths: Theora's Y'CbCr and NV12's are the same values in a
    /// different arrangement, so luma is a memcpy and chroma an interleave. 4:2:2 and 4:4:4
    /// chroma is decimated to 4:2:0 on the way, which is what H.264 wants anyway. The
    /// interleave runs on raw pointers because a five-minute 1080p scene is half a million
    /// chroma samples a frame, seven thousand times, and bounds checks make that a long wait.
    private static func fill(
        _ buffer: CVPixelBuffer,
        from planes: [th_img_plane],
        info: th_info,
        width: Int,
        height: Int
    ) throws(VideoConversionFailure) {
        let (chromaX, chromaY): (Int, Int)
        switch info.pixel_fmt {
        case TH_PF_420: (chromaX, chromaY) = (1, 1)
        case TH_PF_422: (chromaX, chromaY) = (1, 0)
        case TH_PF_444: (chromaX, chromaY) = (0, 0)
        default: throw .unsupportedPixelFormat
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let lumaBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
              let chromaBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1),
              let lumaSource = planes[0].data,
              let cbSource = planes[1].data,
              let crSource = planes[2].data else {
            throw .unsupportedPixelFormat
        }

        // The visible picture can sit at an offset inside the coded frame.
        let offsetX = Int(info.pic_x)
        let offsetY = Int(info.pic_y)

        // Luma: a straight row-by-row copy.
        let lumaDestinationStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let lumaSourceStride = Int(planes[0].stride)
        let copyWidth = min(width, Int(planes[0].width) - offsetX)

        for row in 0..<height {
            let sourceRow = lumaSource.advanced(by: (row + offsetY) * lumaSourceStride + offsetX)
            let destinationRow = lumaBase.advanced(by: row * lumaDestinationStride)
            memcpy(destinationRow, sourceRow, copyWidth)
        }

        // Chroma: interleave Cb and Cr into NV12's single plane.
        let chromaDestinationStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        let chromaHeight = (height + 1) / 2
        let cbStride = Int(planes[1].stride)
        let crStride = Int(planes[2].stride)
        // One source sample per output column for 4:2:0, every second one for full-width chroma.
        let columnStep = 2 >> chromaX
        let chromaOffsetX = offsetX >> chromaX
        let chromaOffsetY = offsetY >> chromaY

        // Never read past the source plane, whatever the picture offset.
        let availableColumns = (Int(planes[1].width) - chromaOffsetX) / columnStep
        let chromaWidth = max(0, min((width + 1) / 2, availableColumns))

        let destination = chromaBase.assumingMemoryBound(to: UInt8.self)

        for row in 0..<chromaHeight {
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
