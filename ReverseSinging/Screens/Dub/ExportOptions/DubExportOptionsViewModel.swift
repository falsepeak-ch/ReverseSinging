//
//  DubExportOptionsViewModel.swift
//  ReverseSinging
//
//  The export's choices: which stretch of the film, and how the booth sits in it
//

import SwiftUI
import Combine
import AVFoundation
import DubCompositing
import DubloonFoundation

/// Holds the choices an export is being configured with, and reads what the diagram needs
/// from the pack: the scene's real shape, and a frame of the performer.
@MainActor
final class DubExportOptionsViewModel: ObservableObject {

    let pack: DubPack
    /// Non-nil when this is one line's own export, reached from its row in the list.
    let line: DubLine?
    /// Whether there is any booth footage to composite at all.
    let hasBoothFootage: Bool
    /// How long the finished file runs, for the selected cut.
    private let runtime: (DubCut) -> TimeInterval

    @Published var cut: DubCut
    @Published var frame: DubBoothFrame
    /// Whether the performer's own footage goes into the file. Only the vertical frames can
    /// be rendered without it, so only they show the switch.
    @Published var includesBooth: Bool
    /// The scene picture's shape, read from the pack's own video. Nil until it has loaded, and
    /// for packs that have no video and are exported as a slideshow.
    @Published private(set) var sceneSize: CGSize?
    /// A frame lifted out of one of the booth clips, so the diagram can show the performer
    /// rather than a labelled rectangle. Nil for a scene that was never filmed.
    @Published private(set) var boothStill: UIImage?

    init(
        pack: DubPack,
        line: DubLine?,
        hasBoothFootage: Bool,
        runtime: @escaping (DubCut) -> TimeInterval
    ) {
        self.pack = pack
        self.line = line
        self.hasBoothFootage = hasBoothFootage
        self.runtime = runtime

        cut = line.map { DubCut.line($0.slug) } ?? .fullScene
        // A single line is four seconds, and four seconds is a vertical post. The whole scene
        // is not, so it keeps the shape it has always exported in.
        frame = hasBoothFootage ? (line == nil ? .corner : .stacked) : .off
        includesBooth = hasBoothFootage
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "DubExportOptions")
    }

    func loadSceneSize() async {
        sceneSize = await DubBoothComposer.sceneDisplaySize(of: pack)
    }

    func loadBoothStill() async {
        boothStill = await Self.boothStill(in: pack)
    }

    /// A frame from the first booth clip this pack has, for the diagram.
    ///
    /// Half a second in rather than at zero: the first frame of a take is the performer still
    /// arranging their face, which is nobody's idea of a thumbnail.
    private static func boothStill(in pack: DubPack) async -> UIImage? {
        guard let line = pack.lines.first(where: { pack.hasBoothTake(for: $0) }) else { return nil }

        let asset = AVURLAsset(url: pack.boothTakeURL(for: line))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)

        guard let image = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)).image
        else { return nil }

        return UIImage(cgImage: image)
    }

    // MARK: - Layout

    /// The booth's own shape, for laying out the diagram before any footage is opened. Every
    /// clip `BoothRecorder` writes is portrait; the exact numbers only move the inset by a
    /// hair, and the render reads the real ones.
    static let boothDisplaySize = CGSize(width: 720, height: 1280)

    /// The shape the export is laid out around: the pack's own video, or the 16:9 slideshow
    /// that stands in for a pack that has none.
    var sceneDisplaySize: CGSize {
        sceneSize ?? CGSize(width: 1280, height: 720)
    }

    /// Whether the performer will actually be in the file.
    var showsBooth: Bool {
        showsBooth(in: frame)
    }

    /// Whether a frame, if picked, would have the performer in it.
    func showsBooth(in option: DubBoothFrame) -> Bool {
        hasBoothFootage && (includesBooth || !option.isVertical)
    }

    /// Whether a frame can be picked at all. Without booth footage the vertical frames are
    /// still worth having — they reshape the export and draw the waveform strip — but the
    /// ones that exist only to place a face are not.
    func isAvailable(_ option: DubBoothFrame) -> Bool {
        hasBoothFootage || !option.needsCompositing || option.isVertical
    }

    /// The still that stands in for the scene: the line being exported when there is one,
    /// otherwise a frame from the middle of the film rather than its first, which on these
    /// packs is usually a title card.
    var sceneStillURL: URL? {
        if let line { return pack.imageURL(for: line) }
        guard !pack.lines.isEmpty else { return nil }
        return pack.imageURL(for: pack.lines[pack.lines.count / 2])
    }

    // MARK: - Slate

    var runtimeText: String {
        runtime(cut).rsClock
    }

    /// The shape the file really comes out at.
    ///
    /// The vertical frames render to a fixed 9:16 canvas. Every other frame keeps the scene's
    /// own shape, which is whatever the pack ships — a 4:3 short from 1951 as readily as a
    /// 16:9 one — so this reads it rather than assuming.
    var shapeLabel: String {
        DubBoothLayout.make(
            frame: frame,
            sceneDisplaySize: sceneDisplaySize,
            boothDisplaySize: Self.boothDisplaySize
        ).renderSize.rsAspectLabel
    }

    /// Whether the booth goes into the render. Never without footage, whatever the switch says.
    var exportsBooth: Bool {
        includesBooth && hasBoothFootage
    }
}
