// Composes Dubloon the Game's App Store artwork from the game's own art: the stage scenes, the
// host and the props. No text, because the App Store lays its own over these.
//
//   swift fastlane/screenshots_game/compose_store_art.swift <scenes dir> <out dir>
//
// <scenes dir> holds the scene backgrounds from DesignAssets/BackgroundScenes-2026-10-18,
// enlarged to 3840 on their long side: arena.png, rooftop.png, studio.png, studio-portrait.png.
// Writes header.png (3840x1646, product page header, a fixed size), search.png (2400x1600),
// event-card.png (2560x1440) and event-details.png (1440x2560), all opaque. The last three are
// sized so the host, 1536 px tall in the kit, is drawn at about her own resolution.

import AppKit
import CoreGraphics

let scenes = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2])
let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let kit = repo.appendingPathComponent("DesignAssets")

func load(_ url: URL) -> CGImage {
    guard let image = NSImage(contentsOf: url), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("can't read \(url.path)")
    }
    return cg
}
func host(_ pose: String) -> CGImage { load(kit.appendingPathComponent("voxhop-game-kit/Host.atlas/host_\(pose).png")) }
func object(_ name: String) -> CGImage { load(kit.appendingPathComponent("voxhop-asset-variations/Objects.atlas/\(name).png")) }
func original(_ name: String) -> CGImage { load(kit.appendingPathComponent("voxhop-asset-variations/Originals/\(name).png")) }
func prop(_ name: String) -> CGImage { load(kit.appendingPathComponent("voxhop-animation-kit/Props.atlas/\(name).png")) }
func scene(_ name: String) -> CGImage { load(scenes.appendingPathComponent("\(name).png")) }

let navy = CGColor(srgbRed: 0.047, green: 0.133, blue: 0.200, alpha: 1)
let cyan = CGColor(srgbRed: 0.373, green: 0.827, blue: 0.953, alpha: 1)
let warm = CGColor(srgbRed: 1.0, green: 0.92, blue: 0.75, alpha: 1)

/// A canvas with a top-left origin, so every position below reads like a layout.
final class Canvas {
    let size: CGSize
    let ctx: CGContext

    init(_ width: Int, _ height: Int) {
        size = CGSize(width: width, height: height)
        ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.interpolationQuality = .high
    }

    /// Top-left rect to Core Graphics' bottom-left one.
    func cg(_ rect: CGRect) -> CGRect { CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height) }

    /// Fills the canvas with `image`, cropped to its shape. `focusY` is where the crop sits
    /// vertically, 0 the top and 1 the bottom; `focusX` likewise across.
    func backdrop(_ image: CGImage, focusX: CGFloat = 0.5, focusY: CGFloat = 0.5, zoom: CGFloat = 1) {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let scale = max(size.width / w, size.height / h) * zoom
        let drawn = CGSize(width: w * scale, height: h * scale)
        let rect = CGRect(x: (size.width - drawn.width) * focusX, y: (size.height - drawn.height) * focusY,
                          width: drawn.width, height: drawn.height)
        ctx.draw(image, in: cg(rect))
    }

    /// A soft radial pool of `color`, for light behind or under something.
    func glow(at center: CGPoint, radius: CGFloat, color: CGColor, alpha: CGFloat, squash: CGFloat = 1) {
        ctx.saveGState()
        let p = CGPoint(x: center.x, y: size.height - center.y)
        ctx.translateBy(x: p.x, y: p.y)
        ctx.scaleBy(x: 1, y: squash)
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [color.copy(alpha: alpha)!, color.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
        ctx.restoreGState()
    }

    /// Darkens toward the edges, so the eye lands in the middle.
    func vignette(strength: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.55)
        let radius = hypot(size.width, size.height) * 0.62
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [navy.copy(alpha: 0)!, navy.copy(alpha: 0)!, navy.copy(alpha: strength)!] as CFArray,
                                  locations: [0, 0.55, 1])!
        let p = CGPoint(x: center.x, y: size.height - center.y)
        ctx.drawRadialGradient(gradient, startCenter: p, startRadius: 0, endCenter: p, endRadius: radius, options: [.drawsAfterEndLocation])
    }

    /// A vertical wash of navy over the bottom `fraction`, for the store's own lettering.
    func floorShade(fraction: CGFloat, alpha: CGFloat) {
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [navy.copy(alpha: 0)!, navy.copy(alpha: alpha)!] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height * fraction), end: .zero, options: [])
    }

    /// Draws `image` `height` tall, centred on `x`, its bottom at `bottom`, turned `degrees`,
    /// with the kit's hard navy drop shadow under it.
    func place(_ image: CGImage, x: CGFloat, bottom: CGFloat, height: CGFloat, degrees: CGFloat = 0,
               shadow: CGFloat = 0.5, contact: Bool = false, blend: CGBlendMode = .normal, alpha: CGFloat = 1) {
        let width = height * CGFloat(image.width) / CGFloat(image.height)
        if contact {
            // The pool of shade a figure stands in.
            glow(at: CGPoint(x: x, y: bottom - height * 0.012), radius: width * 0.42, color: navy, alpha: 0.55, squash: 0.16)
        }
        ctx.saveGState()
        ctx.setBlendMode(blend)
        ctx.setAlpha(alpha)
        let center = CGPoint(x: x, y: size.height - (bottom - height / 2))
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: -degrees * .pi / 180)
        if shadow > 0 {
            ctx.setShadow(offset: CGSize(width: 0, height: -height * 0.025), blur: height * 0.05, color: navy.copy(alpha: shadow))
        }
        ctx.draw(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        ctx.restoreGState()
    }

    func write(_ name: String) {
        let url = out.appendingPathComponent(name)
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        try! rep.representation(using: .png, properties: [:])!.write(to: url)
        print("\(name): \(Int(size.width))x\(Int(size.height))")
    }
}

try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// MARK: - Product page header, 3840x1646

// The arena, the host centre stage under a spotlight; the film on her left, the sounds on her
// right: the two games, without a word.
do {
    let c = Canvas(3840, 1646)
    c.backdrop(scene("arena"), focusY: 0.78)
    c.glow(at: CGPoint(x: 1920, y: 820), radius: 1100, color: cyan, alpha: 0.30)
    c.place(prop("light_beam"), x: 1920, bottom: 1600, height: 1650, shadow: 0, blend: .screen, alpha: 0.55)
    c.glow(at: CGPoint(x: 1920, y: 1540), radius: 760, color: warm, alpha: 0.35, squash: 0.2)

    // The film, stage left.
    c.place(object("film-reel"), x: 900, bottom: 1500, height: 470, degrees: -8, contact: true)
    c.place(object("clapperboard"), x: 1220, bottom: 1060, height: 520, degrees: -12)

    // The sounds, stage right.
    c.place(original("imitate-cat"), x: 2600, bottom: 1080, height: 500, degrees: 8)
    c.place(original("imitate-duck"), x: 2960, bottom: 1500, height: 470, degrees: 6, contact: true)
    c.place(prop("music_note"), x: 2320, bottom: 600, height: 260, degrees: 14)
    c.place(prop("music_note"), x: 3260, bottom: 860, height: 200, degrees: -10)

    c.place(host("delight"), x: 1920, bottom: 1590, height: 1440, shadow: 0.35, contact: true)
    c.vignette(strength: 0.55)
    c.write("header.png")
}

// MARK: - Search results, 3:2

// The rooftop at night: the host calling it out, the megaphone and the film in the air, a mic
// and a lion on the floor. Sized so the host draws at her own resolution.
do {
    let c = Canvas(2400, 1600)
    c.backdrop(scene("rooftop"), focusX: 0.5, focusY: 0.6)
    c.glow(at: CGPoint(x: 1200, y: 850), radius: 850, color: cyan, alpha: 0.28)
    c.place(prop("light_beam"), x: 1200, bottom: 1560, height: 1500, shadow: 0, blend: .screen, alpha: 0.5)

    c.place(object("clapperboard"), x: 560, bottom: 820, height: 400, degrees: -12)
    c.place(original("imitate-lion"), x: 470, bottom: 1500, height: 400, degrees: 4, contact: true)
    c.place(object("megaphone"), x: 1840, bottom: 760, height: 420, degrees: -14)
    c.place(object("microphone"), x: 1900, bottom: 1500, height: 500, degrees: 4, contact: true)
    c.place(prop("music_note"), x: 2150, bottom: 380, height: 170, degrees: 12)

    c.place(host("talk"), x: 1200, bottom: 1560, height: 1440, shadow: 0.35, contact: true)
    c.vignette(strength: 0.5)
    c.write("search.png")
}

// MARK: - In-app event card, 16:9

// The recording studio: the host by the mic, headphones and the reel in, room at the foot for
// the event's own title.
do {
    let c = Canvas(2560, 1440)
    c.backdrop(scene("studio"), focusY: 0.55)
    c.glow(at: CGPoint(x: 1280, y: 700), radius: 850, color: cyan, alpha: 0.25)
    c.place(prop("light_beam"), x: 1280, bottom: 1340, height: 1300, shadow: 0, blend: .screen, alpha: 0.45)

    c.place(object("headphones"), x: 740, bottom: 720, height: 360, degrees: -12)
    c.place(object("film-reel"), x: 700, bottom: 1250, height: 360, degrees: -6, contact: true)
    c.place(object("microphone"), x: 1860, bottom: 1250, height: 520, degrees: 5, contact: true)
    c.place(prop("music_note"), x: 2080, bottom: 520, height: 180, degrees: 12)

    c.place(host("delight"), x: 1280, bottom: 1360, height: 1300, shadow: 0.35, contact: true)
    c.vignette(strength: 0.5)
    c.floorShade(fraction: 0.3, alpha: 0.55)
    c.write("event-card.png")
}

// MARK: - In-app event details, 9:16

do {
    let c = Canvas(1440, 2560)
    c.backdrop(scene("studio-portrait"), focusY: 0.5)
    c.glow(at: CGPoint(x: 720, y: 1350), radius: 900, color: cyan, alpha: 0.25)
    c.place(prop("light_beam"), x: 720, bottom: 2250, height: 2100, shadow: 0, blend: .screen, alpha: 0.45)

    c.place(object("clapperboard"), x: 330, bottom: 700, height: 330, degrees: -12)
    c.place(original("imitate-cat"), x: 1110, bottom: 660, height: 320, degrees: 8)
    c.place(prop("music_note"), x: 720, bottom: 400, height: 150, degrees: 12)
    c.place(object("film-reel"), x: 250, bottom: 2230, height: 300, degrees: -6, contact: true)
    c.place(original("imitate-duck"), x: 1190, bottom: 2230, height: 300, degrees: 6, contact: true)

    c.place(host("delight"), x: 720, bottom: 2260, height: 1500, shadow: 0.35, contact: true)
    c.vignette(strength: 0.5)
    c.floorShade(fraction: 0.22, alpha: 0.6)
    c.write("event-details.png")
}
