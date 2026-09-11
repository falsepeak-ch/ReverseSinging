//
//  TheoraTranscoder.swift
//  DubPackKit
//

public import Foundation
import XiphTheora

/// Turns an Ogg Theora scene video into an H.264 MP4 that AVFoundation can play.
///
/// Dub packs ship their scene as `dub_video.ogv`, which no Apple framework decodes. Rather
/// than carry a decoder around at playback time, the installer converts the file once and
/// throws the original away, so everything downstream deals in ordinary H.264. Decoding is
/// libtheora; encoding is VideoToolbox through `AVAssetWriter`.
public enum TheoraTranscoder {

    /// What a finished conversion wrote.
    public struct Output: Sendable, Hashable {
        /// Frames written, duplicates included.
        public let frameCount: Int
        /// The file's length, from the last frame's index rather than measured back off disk.
        public let duration: TimeInterval
    }

    /// How much of the source is read at a time when feeding the Ogg demuxer.
    private static let readChunkSize = 64 * 1024

    /// Decodes `source` and writes an H.264 MP4 to `destination`, replacing anything there.
    ///
    /// Blocking and CPU-bound: call it off the main actor. `progress` reports 0...1 by how
    /// much of the source has been consumed, because a feature-length scene takes minutes and
    /// a silent bar reads as a hang.
    @discardableResult
    public static func transcode(
        ogv source: URL,
        to destination: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws(VideoConversionFailure) -> Output {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: source)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
        } catch {
            throw .unreadableSource(detail: error.localizedDescription)
        }
        defer { try? handle.close() }

        let totalBytes = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 0
        var bytesRead = 0
        // A 150 MB scene is ~2,400 chunks; reporting every one would hop to the main actor far
        // more often than a progress bar can show.
        var lastReported = 0.0

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

        var setup: OpaquePointer?
        defer { if setup != nil { th_setup_free(setup) } }

        var decoder: OpaquePointer?
        defer { if decoder != nil { th_decode_free(decoder) } }

        var writer: TheoraFrameWriter?
        var headersRemaining = true
        var foundTheora = false
        // Where the next frame goes when the stream gives no granule position to read it from.
        var nextFrameIndex: Int64 = 0
        var framesWritten = 0

        readLoop: while true {
            var page = ogg_page()

            // Drain every page already buffered before reading more of the file. A status of
            // -1 is a hole in the stream, not the end of the buffer: stopping there would
            // leave whole pages unread behind the damage.
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
                    // A pack's container also carries a Vorbis track; skip anything that is
                    // not the stream locked onto.
                    continue
                }

                guard ogg_stream_pagein(&stream, &page) == 0 else { continue }

                var packet = ogg_packet()
                while ogg_stream_packetout(&stream, &packet) == 1 {
                    if headersRemaining {
                        let status = th_decode_headerin(&info, &comment, &setup, &packet)

                        if status < 0 {
                            // Some other beginning-of-stream, not Theora: keep looking.
                            guard foundTheora else {
                                ogg_stream_clear(&stream)
                                streamInitialised = false
                                break
                            }
                            throw .badHeaders
                        }

                        foundTheora = true
                        guard status == 0 else { continue }

                        // Headers done; this packet is the first frame.
                        headersRemaining = false
                        guard let context = th_decode_alloc(&info, setup) else { throw .decoderUnavailable }
                        decoder = context
                        writer = try TheoraFrameWriter(destination: destination, info: info)
                    }

                    guard let decoder, let writer else { continue }

                    var granulePosition: ogg_int64_t = 0
                    let status = th_decode_packetin(decoder, &packet, &granulePosition)

                    // `TH_DUPFRAME` is not a failure. The packet repeats the previous picture,
                    // and libtheora's player example skips the redraw because that picture is
                    // already on screen. A transcoder is the other case: the frame still owns
                    // its slot on the timeline and must be written again. Dropping it shortens
                    // the file and pulls everything after it earlier.
                    guard status == 0 || status == TH_DUPFRAME else { continue }

                    // The granule position carries the frame's absolute index, so the timeline
                    // is built from it rather than a running counter: a packet that fails to
                    // decode then holds the previous frame a beat longer instead of shifting
                    // the rest of the scene. Floored at the counter because presentation times
                    // must strictly increase, and frames before the first page boundary report
                    // no granule position at all.
                    var frameIndex = granulePosition >= 0
                        ? th_granule_frame(UnsafeMutableRawPointer(decoder), granulePosition)
                        : -1
                    frameIndex = max(frameIndex, nextFrameIndex)
                    nextFrameIndex = frameIndex + 1

                    // Still valid after a duplicate: the call hands back the picture already
                    // in the frame buffer.
                    var planes = [th_img_plane](
                        repeating: th_img_plane(width: 0, height: 0, stride: 0, data: nil),
                        count: 3
                    )
                    guard th_decode_ycbcr_out(decoder, &planes) == 0 else { continue }

                    try writer.append(planes: planes, info: info, at: frameIndex)
                    framesWritten += 1
                }
            }

            let chunk: Data
            do {
                chunk = try handle.read(upToCount: readChunkSize) ?? Data()
            } catch {
                throw .unreadableSource(detail: error.localizedDescription)
            }
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

        guard foundTheora else { throw .notTheora }
        guard let writer, framesWritten > 0 else { throw .noFrames }

        let output = try writer.finish()
        progress?(1)
        return output
    }
}
