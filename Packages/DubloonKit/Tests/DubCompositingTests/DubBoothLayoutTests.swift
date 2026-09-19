//
//  DubBoothLayoutTests.swift
//  DubCompositingTests
//
//  The booth lands where the layout says it does
//

import CoreGraphics
import Testing
import DubCompositing

/// Pure geometry, checked without touching AVFoundation.
@Suite("Booth Layout")
struct DubBoothLayoutTests {

    private let scene = CGSize(width: 1280, height: 720)
    private let booth = CGSize(width: 720, height: 1280)

    @Test func offKeepsTheSceneAloneAtItsOwnSize() {
        let layout = DubBoothLayout.make(frame: .off, sceneDisplaySize: scene, boothDisplaySize: booth)

        #expect(layout.renderSize == scene)
        #expect(layout.boothRect == nil)
    }

    /// The inset takes the booth's own aspect so filling it is exact. If it ever stopped
    /// matching, the booth would spill over the picture with nothing drawn after to hide it.
    @Test func theCornerInsetMatchesTheBoothAspectExactly() throws {
        let layout = DubBoothLayout.make(frame: .corner, sceneDisplaySize: scene, boothDisplaySize: booth)

        let rect = try #require(layout.boothRect)
        let insetAspect = rect.width / rect.height
        let boothAspect = booth.width / booth.height

        #expect(abs(insetAspect - boothAspect) < 0.01)
        #expect(layout.boothIsOnTop, "the inset has to sit over the picture")
        #expect(layout.renderSize == scene, "a corner inset must not change the output shape")
    }

    /// The check that a pure aspect-ratio test misses: an inset can match the booth exactly
    /// and still be most of the picture. Sized by the frame's width, this one came out 70%
    /// of its height.
    @Test func theCornerInsetIsAnInsetRatherThanASecondPicture() throws {
        let layout = DubBoothLayout.make(frame: .corner, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)

        #expect(rect.height / scene.height < 0.4, "an inset taller than 40% of the frame is not an inset")
        #expect(rect.width / scene.width < 0.25)
        #expect(rect.height / scene.height > 0.2, "and one too small to read a face in is no use either")
    }

    @Test func theCornerInsetSitsInsideTheFrame() throws {
        let layout = DubBoothLayout.make(frame: .corner, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)

        #expect(rect.minX > 0)
        #expect(rect.minY > 0)
        #expect(rect.maxX < scene.width)
        #expect(rect.maxY < scene.height)
    }

    /// 9:16, scene on top, and the three bands meet with no gap and no overlap.
    @Test func stackedRendersPortraitWithTheSceneOnTop() throws {
        let layout = DubBoothLayout.make(frame: .stacked, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)
        let wave = try #require(layout.waveRect)

        #expect(layout.renderSize == CGSize(width: 1080, height: 1920))
        #expect(layout.sceneRect.minY == 0)
        #expect(rect.minY == layout.sceneRect.maxY, "the bands must meet exactly")
        #expect(rect.maxY == wave.minY, "the booth runs down to the waveform and no further")
        #expect(wave.maxY == layout.renderSize.height)
        #expect(
            !layout.boothIsOnTop,
            "the booth overflows its band upward, so the scene has to be drawn after it"
        )
    }

    /// The mirror of `stacked`: the face goes on top, the film underneath.
    @Test func reactionPutsTheBoothAboveTheScene() throws {
        let layout = DubBoothLayout.make(frame: .reaction, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)
        let wave = try #require(layout.waveRect)

        #expect(layout.renderSize == CGSize(width: 1080, height: 1920))
        #expect(rect.minY == 0, "the booth starts at the top of the frame")
        #expect(rect.maxY == layout.sceneRect.minY, "the bands must meet exactly")
        #expect(layout.sceneRect.maxY == wave.minY)
        #expect(
            !layout.boothIsOnTop,
            "the booth overflows downward into the scene, so the scene is drawn after it"
        )
    }

    /// The two vertical frames use exactly the same bands, in the other order.
    @Test func theVerticalFramesAreOneAnothersMirror() throws {
        let stacked = DubBoothLayout.make(frame: .stacked, sceneDisplaySize: scene, boothDisplaySize: booth)
        let reaction = DubBoothLayout.make(frame: .reaction, sceneDisplaySize: scene, boothDisplaySize: booth)

        #expect(stacked.renderSize == reaction.renderSize)
        #expect(stacked.waveRect == reaction.waveRect)
        #expect(stacked.sceneRect.size == reaction.sceneRect.size)
        #expect(try #require(stacked.boothRect).size == (try #require(reaction.boothRect)).size)
        #expect(stacked.sceneRectAlone == reaction.sceneRectAlone,
                "with nobody in the booth the two frames are the same picture")
    }

    /// The fix for the band of black that a scene with gaps used to export.
    @Test func aVerticalFrameGivesTheBoothBandBackWhenThereIsNoFootageForIt() throws {
        for frame in [DubBoothFrame.stacked, .reaction] {
            let layout = DubBoothLayout.make(frame: frame, sceneDisplaySize: scene, boothDisplaySize: booth)
            let wave = try #require(layout.waveRect)

            #expect(layout.sceneRectAlone.size == layout.sceneRect.size,
                    "the scene moves rather than resizing, so each line reads as a cut")
            #expect(
                abs(layout.sceneRectAlone.midY - wave.minY / 2) < 1,
                "the scene is centred in the picture area, so what black is left is symmetrical"
            )
            #expect(layout.sceneRectAlone.minY > 0, "and it is no longer pinned to an edge")
        }
    }

    /// The same gap, in the landscape frame that has one.
    @Test func splitGivesTheWholeFrameBackWhenTheBoothIsNotRolling() {
        let layout = DubBoothLayout.make(frame: .split, sceneDisplaySize: scene, boothDisplaySize: booth)

        #expect(layout.sceneRectAlone == CGRect(origin: .zero, size: layout.renderSize))
    }

    /// A pack that is already portrait leaves no room for a face, and is not cropped to make
    /// some. It still gets the vertical canvas and the waveform.
    @Test func aPortraitPackKeepsItsPictureRatherThanMakingRoomForTheBooth() {
        let layout = DubBoothLayout.make(
            frame: .stacked,
            sceneDisplaySize: CGSize(width: 1080, height: 1920),
            boothDisplaySize: booth
        )

        #expect(layout.boothRect == nil)
        #expect(layout.waveRect != nil)
        #expect(layout.sceneRect == layout.sceneRectAlone)
    }

    /// Only the frames that stand up on their own are worth rendering with no booth in them.
    @Test func onlyTheVerticalFramesAreVerticalOnes() {
        #expect(DubBoothFrame.stacked.isVertical)
        #expect(DubBoothFrame.reaction.isVertical)
        #expect(!DubBoothFrame.off.isVertical)
        #expect(!DubBoothFrame.corner.isVertical)
        #expect(!DubBoothFrame.split.isVertical)
    }

    /// Only the vertical frames carry a strip; the rest are the shapes they always were.
    @Test func onlyTheVerticalFramesReserveAWaveformStrip() {
        for frame in DubBoothFrame.allCases {
            let layout = DubBoothLayout.make(frame: frame, sceneDisplaySize: scene, boothDisplaySize: booth)
            #expect((layout.waveRect != nil) == frame.isVertical, "\(frame)")
        }
    }

    @Test func splitGivesEachHalfTheFullHeight() throws {
        let layout = DubBoothLayout.make(frame: .split, sceneDisplaySize: scene, boothDisplaySize: booth)
        let rect = try #require(layout.boothRect)

        #expect(layout.sceneRect.width + rect.width == scene.width)
        #expect(layout.sceneRect.height == scene.height)
        #expect(rect.height == scene.height)
        #expect(rect.minX == layout.sceneRect.maxX)
        #expect(layout.boothIsOnTop, "the scene overflows right, so the booth has to cover it")
    }

    /// A zero anywhere would divide by it. Packs whose video failed to load have arrived here.
    @Test func aDegenerateSourceFallsBackRatherThanDividingByZero() {
        let layout = DubBoothLayout.make(
            frame: .stacked,
            sceneDisplaySize: .zero,
            boothDisplaySize: .zero
        )
        #expect(layout.renderSize.width > 0)
        #expect(layout.renderSize.height > 0)
    }

    /// H.264 refuses odd dimensions.
    @Test func renderSizesAreAlwaysEven() {
        let layout = DubBoothLayout.make(
            frame: .corner,
            sceneDisplaySize: CGSize(width: 1281, height: 721),
            boothDisplaySize: booth
        )
        #expect(Int(layout.renderSize.width) % 2 == 0)
        #expect(Int(layout.renderSize.height) % 2 == 0)
    }

    @Test func fillingARectCoversItEntirely() {
        let rect = CGRect(x: 100, y: 50, width: 400, height: 300)
        let transform = DubBoothLayout.fillTransform(displaySize: booth, into: rect)
        let covered = CGRect(origin: .zero, size: booth).applying(transform)

        #expect(covered.minX <= rect.minX + 0.5)
        #expect(covered.minY <= rect.minY + 0.5)
        #expect(covered.maxX >= rect.maxX - 0.5)
        #expect(covered.maxY >= rect.maxY - 0.5)
    }
}
