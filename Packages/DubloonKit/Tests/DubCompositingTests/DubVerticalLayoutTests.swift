//
//  DubVerticalLayoutTests.swift
//  DubCompositingTests
//
//  The Vertical post, its picture-in-picture and the mark
//

import CoreGraphics
import Testing
import DubCompositing

@Suite("Vertical Layout")
struct DubVerticalLayoutTests {

    private let widescreen = CGSize(width: 1280, height: 720)
    private let academy = CGSize(width: 640, height: 480)
    private let booth = CGSize(width: 720, height: 1280)
    private let canvas = CGRect(x: 0, y: 0, width: 1080, height: 1920)

    private func layout(
        _ scene: CGSize,
        corner: DubPipCorner = .bottomRight
    ) -> DubBoothLayout {
        DubBoothLayout.make(frame: .vertical, sceneDisplaySize: scene, boothDisplaySize: booth, pipCorner: corner)
    }

    @Test func rendersAt1080By1920() {
        #expect(layout(widescreen).renderSize == CGSize(width: 1080, height: 1920))
        #expect(layout(academy).renderSize == CGSize(width: 1080, height: 1920))
    }

    /// Full width, its own aspect, centred: letterboxed, never cropped or stretched.
    @Test func theSceneIsLetterboxedAtFullWidth() {
        let rect = layout(widescreen).sceneRect

        #expect(rect.width == 1080)
        #expect(abs(rect.width / rect.height - widescreen.width / widescreen.height) < 0.01)
        #expect(abs(rect.midY - 960) <= 2, "centred, so the bars are equal")
        #expect(layout(widescreen).sceneRectAlone == rect, "the scene does not move when the booth leaves")
    }

    /// A scene taller than 9:16 is fitted by height instead, so none of it is cut off.
    @Test func aTallSceneIsFittedRatherThanCropped() {
        let rect = layout(CGSize(width: 600, height: 1400)).sceneRect
        #expect(rect.height == 1920)
        #expect(rect.width < 1080)
        #expect(canvas.contains(rect))
    }

    @Test func thePipIsSmallPortraitAndRounded() throws {
        let layout = layout(widescreen)
        let pip = try #require(layout.boothRect)

        #expect(pip.height < pip.width * 2, "portrait")
        #expect(pip.height > pip.width)
        #expect(abs(pip.width / pip.height - booth.width / booth.height) < 0.01, "the booth's own shape, so nothing is cropped")
        #expect(pip.width / 1080 < 0.25, "small: a picture-in-picture, not a second picture")
        #expect(layout.boothCornerRadius > 0)
        #expect(layout.boothIsOnTop)
    }

    /// The default: bottom-right, and inside the lower bar for an ordinary widescreen scene.
    @Test func byDefaultThePipSitsBottomRightInsideTheLowerBar() throws {
        let layout = layout(widescreen)
        let pip = try #require(layout.boothRect)

        #expect(pip.midX > 540)
        #expect(pip.minY >= layout.sceneRect.maxY, "in the black bar, not over the film")
        #expect(layout.boothIsInBar)
    }

    /// A squarer scene leaves a shallower bar, and the booth overlaps the scene's corner.
    @Test func whenTheBarIsTooShallowThePipOverlapsTheScenesCorner() throws {
        let layout = layout(academy)
        let pip = try #require(layout.boothRect)

        #expect(pip.minY < layout.sceneRect.maxY)
        #expect(!layout.boothIsInBar)
    }

    /// Clear of the platform's status strip, caption and action column.
    @Test func everyCornerKeepsTheSafeMargins() throws {
        for corner in DubPipCorner.allCases {
            let pip = try #require(layout(widescreen, corner: corner).boothRect)

            #expect(pip.minX >= 1080 * DubBoothLayout.Vertical.sideInset - 1, "\(corner)")
            #expect(1080 - pip.maxX >= 1080 * DubBoothLayout.Vertical.sideInset - 1, "\(corner)")
            #expect(pip.minY >= 1920 * DubBoothLayout.Vertical.topInset - 1, "\(corner)")
            #expect(1920 - pip.maxY >= 1920 * DubBoothLayout.Vertical.bottomInset - 1, "\(corner)")
        }
    }

    @Test func theCornerChoiceMovesThePip() throws {
        let bottomLeft = try #require(layout(widescreen, corner: .bottomLeft).boothRect)
        let topRight = try #require(layout(widescreen, corner: .topRight).boothRect)

        #expect(bottomLeft.midX < 540)
        #expect(bottomLeft.midY > 960)
        #expect(topRight.midX > 540)
        #expect(topRight.midY < 960)
    }

    // MARK: Watermark

    @Test func theMarkIsTopLeftInsideTheSafeMarginInVertical() {
        let mark = layout(widescreen).watermarkRect

        #expect(mark.minX >= 1080 * DubBoothLayout.Vertical.sideInset - 1)
        #expect(mark.minY >= 1920 * DubBoothLayout.Vertical.topInset - 1)
        #expect(mark.midX < 540 && mark.midY < 960, "the top-left corner")
        #expect(mark.maxY <= layout(widescreen).sceneRect.minY, "inside the top bar for a widescreen scene")
    }

    @Test func theMarkNeverTouchesThePipInAnyCorner() throws {
        for corner in DubPipCorner.allCases {
            let layout = layout(academy, corner: corner)
            let pip = try #require(layout.boothRect)
            #expect(!layout.watermarkRect.intersects(pip), "\(corner)")
        }
    }

    /// Every frame carries the mark, inside the picture, clear of the booth, and scaled to the
    /// output rather than fixed in pixels.
    @Test func everyFrameHasAMarkClearOfTheBooth() {
        for frame in DubBoothFrame.allCases {
            let layout = DubBoothLayout.make(frame: frame, sceneDisplaySize: widescreen, boothDisplaySize: booth)
            let mark = layout.watermarkRect
            let bounds = CGRect(origin: .zero, size: layout.renderSize)

            #expect(mark.width > 0 && mark.height > 0, "\(frame)")
            #expect(bounds.contains(mark), "\(frame)")
            if let boothRect = layout.boothRect {
                #expect(!mark.intersects(boothRect), "\(frame)")
            }
            if let waveRect = layout.waveRect {
                #expect(!mark.intersects(waveRect), "\(frame)")
            }
            #expect(mark.width / layout.renderSize.width < 0.3, "\(frame): small")
        }
    }

    @Test func theMarkScalesWithTheOutput() {
        let small = DubBoothLayout.make(frame: .off, sceneDisplaySize: CGSize(width: 640, height: 360), boothDisplaySize: booth)
        let large = DubBoothLayout.make(frame: .off, sceneDisplaySize: CGSize(width: 1920, height: 1080), boothDisplaySize: booth)

        #expect(abs(large.watermarkRect.width / small.watermarkRect.width - 3) < 0.1)
    }

    @Test func theMarkKeepsTheLogosShape() {
        let mark = layout(widescreen).watermarkRect
        #expect(abs(mark.width / mark.height - DubBoothLayout.defaultWatermarkAspect) < 0.1)
    }
}
