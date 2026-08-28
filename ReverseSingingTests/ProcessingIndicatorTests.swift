//
//  ProcessingIndicatorTests.swift
//  ReverseSingingTests
//
//  The import overlay actually drawing, and drawing its progress
//

import Testing
import SwiftUI
import UIKit
@testable import ReverseSinging

@Suite("Processing Indicator")
@MainActor
struct ProcessingIndicatorTests {

    /// Rasterises a view and returns its pixels, so "does this draw anything" can be
    /// answered without depending on the simulator's UI being in a particular state.
    private func render(_ view: some View, size: CGSize) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        let image = try #require(renderer.uiImage)
        let cgImage = try #require(image.cgImage)

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        let context = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    /// Fraction of pixels that are not fully transparent.
    private func coverage(_ pixels: [UInt8]) -> Double {
        var opaque = 0
        for index in stride(from: 3, to: pixels.count, by: 4) where pixels[index] > 8 {
            opaque += 1
        }
        return Double(opaque) / Double(pixels.count / 4)
    }

    @Test func drawsSomethingWhenIndeterminate() throws {
        let pixels = try render(
            ProcessingIndicator(message: "Importing pack…"),
            size: CGSize(width: 320, height: 320)
        )
        #expect(coverage(pixels) > 0.05, "the overlay must actually paint something")
    }

    /// The determinate bar is the whole point: a minutes-long conversion behind a bare
    /// spinner is indistinguishable from a hang.
    @Test func drawsMoreAsProgressAdvances() throws {
        let size = CGSize(width: 320, height: 320)

        let empty = try render(
            ProcessingIndicator(message: "Converting scene video…", progress: 0.0),
            size: size
        )
        let full = try render(
            ProcessingIndicator(message: "Converting scene video…", progress: 1.0),
            size: size
        )

        #expect(coverage(empty) > 0.05, "determinate overlay must draw")

        // Compare pixels rather than alpha coverage: the panel is opaque either way, so
        // what changes is colour. The filled track and the percentage label.
        #expect(empty.count == full.count)
        var differing = 0
        for index in 0..<min(empty.count, full.count) where empty[index] != full[index] {
            differing += 1
        }
        #expect(differing > 200,
                "0% and 100% must not render identically; only \(differing) bytes differed")
    }
}
