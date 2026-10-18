//
//  DubWatermark.swift
//  ReverseSinging
//
//  The Dubloon mark every export carries
//

import CoreGraphics
import DubCompositing
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The app's own lettering, from the asset catalog, for the corner of an export.
///
/// **Always on.** Nothing in Dubloon's Pro rules covers branding: the dub library is Pro as a
/// whole, and an export is only ever made by someone who can dub. So there is no tier that
/// removes the mark, and none is invented here.
nonisolated enum DubWatermark {

    /// The asset: microphone and DUBLOON lettering.
    static let assetName = "icon-lettering"

    /// How strongly the mark is drawn. Present enough to be read in a feed, faint enough not
    /// to compete with the film.
    static let opacity: CGFloat = 0.72

    /// The dark-appearance variant: cream lettering, made to sit on a dark picture, which is
    /// what a film and its letterbox bars are.
    static func image() -> CGImage? {
        #if os(iOS)
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(displayScale: 3)
        ])
        return UIImage(named: assetName, in: .main, compatibleWith: traits)?.cgImage
        #else
        guard let image = NSImage(named: assetName),
              let appearance = NSAppearance(named: .darkAqua) else { return nil }
        var result: CGImage?
        appearance.performAsCurrentDrawingAppearance {
            var rect = CGRect(origin: .zero, size: CGSize(width: image.size.width * 3, height: image.size.height * 3))
            result = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return result
        #endif
    }

    /// The mark's width over its height, for the layout.
    static func aspect(of image: CGImage?) -> CGFloat {
        guard let image, image.height > 0 else { return DubBoothLayout.defaultWatermarkAspect }
        return CGFloat(image.width) / CGFloat(image.height)
    }
}

