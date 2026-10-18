// Composes Dubloon the Game's App Store header and search-result artwork for every locale: one
// stage, the host, the game's logo and the three-line tagline in the game's own lettering.
//
//   swift fastlane/screenshots_game/compose_store_art.swift <scenes dir> <out dir> [locale ...]
//
// <scenes dir> holds the scene backgrounds from DesignAssets/BackgroundScenes-2026-10-18,
// enlarged to 3840 on their long side: arena.png and rooftop.png. The tagline and subtitle come
// from hero_lines.json and each locale's Game.strings, as for the screenshot hero. Writes
// <out>/<locale>/header.png (3840x1646, the product page header's fixed size) and search.png
// (2400x1600, sized so the host, 1536 px tall in the kit, draws at about her own resolution).
// Right-to-left locales are laid out mirrored.

import AppKit
import CoreText

let scenes = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2])
let only = Set(CommandLine.arguments.dropFirst(3))
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let repo = root.deletingLastPathComponent().deletingLastPathComponent()

let navy = NSColor(srgbRed: 0.047, green: 0.133, blue: 0.200, alpha: 1)
let ivory = NSColor(srgbRed: 0.984, green: 0.965, blue: 0.918, alpha: 1)
let cyan = NSColor(srgbRed: 0.373, green: 0.827, blue: 0.953, alpha: 1)
let gold = NSColor(srgbRed: 1.0, green: 0.784, blue: 0.239, alpha: 1)

for name in ["LilitaOne-Regular", "MPLUSRounded1c-Black"] {
    CTFontManagerRegisterFontsForURL(repo.appendingPathComponent("DubloonGame/Resources/Fonts/\(name).ttf") as CFURL, .process, nil)
}

/// The game's display face for a language, as `GameFont` picks it in the app.
func font(for lproj: String, size: CGFloat) -> NSFont {
    let lilita = ["en", "de", "es", "fr", "it", "nl", "da", "sv", "nb", "fi", "pt-PT"]
    if lilita.contains(lproj) { return NSFont(name: "LilitaOne", size: size)! }
    if lproj == "ar" { return NSFont(name: ".SFArabicRounded-Bold", size: size) ?? .systemFont(ofSize: size, weight: .black) }
    if lproj == "th" { return NSFont(name: "Thonburi-Bold", size: size) ?? .systemFont(ofSize: size, weight: .black) }
    return NSFont(name: "RoundedMplus1c-Black", size: size)!
}

func subtitle(_ lproj: String) -> String {
    let path = repo.appendingPathComponent("DubloonGame/Resources/\(lproj).lproj/Game.strings")
    return (NSDictionary(contentsOf: path) as? [String: String])?["game.subtitle"] ?? "The Game"
}

func load(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOf: repo.appendingPathComponent(path)) else { fatalError("can't read \(path)") }
    return image
}
let hostImage = load("DesignAssets/voxhop-game-kit/Host.atlas/host_delight.png")
let logoImage = load("DesignAssets/game-logo/dubloon-game-logo.png")
let beam = load("DesignAssets/voxhop-animation-kit/Props.atlas/light_beam.png")
func scene(_ name: String) -> NSImage { NSImage(contentsOf: scenes.appendingPathComponent("\(name).png"))! }

/// A canvas drawn with AppKit, top-left origin, so positions read like a layout.
final class Canvas {
    let size: CGSize
    let ctx: CGContext

    init(_ width: Int, _ height: Int) {
        size = CGSize(width: width, height: height)
        // Opaque, because the App Store refuses artwork with an alpha channel.
        ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    }

    func backdrop(_ image: NSImage, focusX: CGFloat = 0.5, focusY: CGFloat = 0.5) {
        let scale = max(size.width / image.size.width, size.height / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: (size.width - drawn.width) * focusX, y: (size.height - drawn.height) * focusY,
                              width: drawn.width, height: drawn.height),
                   from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
    }

    func radial(at center: CGPoint, radius: CGFloat, color: NSColor, alpha: CGFloat, squash: CGFloat = 1) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: 1, y: squash)
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 1])!
        ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
        ctx.restoreGState()
    }

    /// Navy rising from one side, so the lettering sits on a calm field: darkest at `from`
    /// (a fraction of the width), clear by `to`.
    func sideShade(darkAt from: CGFloat, clearAt to: CGFloat, alpha: CGFloat) {
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [navy.withAlphaComponent(alpha).cgColor, navy.withAlphaComponent(alpha * 0.75).cgColor,
                                           navy.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 0.45, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width * from, y: 0), end: CGPoint(x: size.width * to, y: 0), options: [])
    }

    func vignette(_ strength: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.5)
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [navy.withAlphaComponent(0).cgColor, navy.withAlphaComponent(0).cgColor,
                                           navy.withAlphaComponent(strength).cgColor] as CFArray,
                                  locations: [0, 0.6, 1])!
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                               endRadius: hypot(size.width, size.height) * 0.6, options: [.drawsAfterEndLocation])
    }

    /// The host standing at `x`, feet on `floor`, `height` tall, in a spotlight, on a pool of shade.
    func host(x: CGFloat, floor: CGFloat, height: CGFloat) {
        let width = height * hostImage.size.width / hostImage.size.height
        radial(at: CGPoint(x: x, y: floor - height * 0.5), radius: height * 0.75, color: cyan, alpha: 0.28)
        let beamHeight = height * 1.15
        let beamWidth = beamHeight * beam.size.width / beam.size.height
        beam.draw(in: CGRect(x: x - beamWidth / 2, y: floor - beamHeight + height * 0.04, width: beamWidth, height: beamHeight),
                  from: .zero, operation: .screen, fraction: 0.5, respectFlipped: true, hints: nil)
        radial(at: CGPoint(x: x, y: floor - height * 0.01), radius: width * 0.45, color: navy, alpha: 0.6, squash: 0.15)
        hostImage.draw(in: CGRect(x: x - width / 2, y: floor - height, width: width, height: height),
                       from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
    }

    /// The wordmark, `width` wide, its top at `top`, from `edge` (its right edge when
    /// `alignRight`). Returns its bottom.
    func logo(edge: CGFloat, top: CGFloat, width: CGFloat, alignRight: Bool) -> CGFloat {
        let height = width * logoImage.size.height / logoImage.size.width
        let x = alignRight ? edge - width : edge
        logoImage.draw(in: CGRect(x: x, y: top, width: width, height: height), from: .zero, operation: .sourceOver,
                  fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
        return top + height
    }

    /// One line in the game's lettering: the fill, a navy outline and a navy lip under it,
    /// shrunk until it fits `maxWidth`. `top` is the top of the line box. Returns its bottom.
    @discardableResult
    func line(_ text: String, lproj: String, size pointSize: CGFloat, color: NSColor,
              edge: CGFloat, top: CGFloat, maxWidth: CGFloat, alignRight: Bool, kern: CGFloat = 0) -> CGFloat {
        var points = pointSize
        while NSAttributedString(string: text, attributes: [.font: font(for: lproj, size: points), .kern: kern * points]).size().width > maxWidth,
              points > pointSize * 0.5 {
            points -= 2
        }
        let f = font(for: lproj, size: points)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignRight ? .right : .left
        paragraph.baseWritingDirection = lproj == "ar" ? .rightToLeft : .leftToRight
        let base: [NSAttributedString.Key: Any] = [.font: f, .paragraphStyle: paragraph, .kern: kern * points]
        let measured = NSAttributedString(string: text, attributes: base).size()
        let rect = CGRect(x: alignRight ? edge - maxWidth : edge, y: top, width: maxWidth, height: measured.height)
        let stroke = points * 0.16
        let lip = points * 0.075

        // Round joins, or the outline spikes out at the sharp corners of the letters.
        ctx.setLineJoin(.round)
        func draw(_ fill: NSColor, outline: Bool, dy: CGFloat) {
            var attributes = base
            attributes[.foregroundColor] = fill
            if outline {
                attributes[.strokeColor] = navy
                attributes[.strokeWidth] = stroke * 2 / points * 100
            }
            NSAttributedString(string: text, attributes: attributes).draw(in: rect.offsetBy(dx: 0, dy: dy))
        }
        draw(navy, outline: true, dy: lip)
        draw(navy, outline: false, dy: lip)
        draw(navy, outline: true, dy: 0)
        draw(color, outline: false, dy: 0)
        return top + measured.height
    }

    func write(_ url: URL) {
        let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
        try! png.write(to: url)
    }
}

/// The type block: logo, subtitle, then the three lines. `scale` sizes the whole block.
func typeBlock(_ c: Canvas, lproj: String, lines: [String], edge: CGFloat, top: CGFloat, width: CGFloat, scale: CGFloat, rtl: Bool) {
    var y = c.logo(edge: rtl ? edge : edge - width * 0.02, top: top, width: width * 0.86, alignRight: rtl)
    y += 18 * scale
    y = c.line(subtitle(lproj).uppercased(with: Locale(identifier: lproj)), lproj: lproj, size: 74 * scale, color: cyan, edge: edge, top: y,
               maxWidth: width, alignRight: rtl, kern: 0.06)
    y += 70 * scale
    let colors = [ivory, cyan, gold]
    let sizes: [CGFloat] = [138, 138, 156]
    for (index, text) in lines.enumerated() {
        y = c.line(text, lproj: lproj, size: sizes[index] * scale, color: colors[index], edge: edge, top: y,
                   maxWidth: width, alignRight: rtl)
        y += 6 * scale
    }
}

let data = try! Data(contentsOf: root.appendingPathComponent("hero_lines.json"))
let locales = try! JSONSerialization.jsonObject(with: data) as! [String: [String: Any]]
let arena = scene("arena"), rooftop = scene("rooftop")

for (locale, entry) in locales.sorted(by: { $0.key < $1.key }) where only.isEmpty || only.contains(locale) {
    let lproj = entry["lproj"] as! String
    let lines = entry["lines"] as! [String]
    let rtl = lproj == "ar"
    let folder = out.appendingPathComponent(locale)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    // Product page header, 3840x1646: the arena, the lettering on one side, the host on the other.
    do {
        let c = Canvas(3840, 1646)
        c.backdrop(arena, focusX: rtl ? 0.35 : 0.65, focusY: 0.78)
        c.sideShade(darkAt: rtl ? 1 : 0, clearAt: rtl ? 0.4 : 0.6, alpha: 0.82)
        c.vignette(0.45)
        c.host(x: rtl ? 1230 : 2610, floor: 1600, height: 1480)
        typeBlock(c, lproj: lproj, lines: lines, edge: rtl ? 3840 - 300 : 300, top: 250, width: 1500, scale: 1, rtl: rtl)
        c.write(folder.appendingPathComponent("header.png"))
    }

    // Search result, 2400x1600: the rooftop at night, same arrangement.
    do {
        let c = Canvas(2400, 1600)
        c.backdrop(rooftop, focusX: rtl ? 0.4 : 0.6, focusY: 0.6)
        c.sideShade(darkAt: rtl ? 1 : 0, clearAt: rtl ? 0.35 : 0.65, alpha: 0.8)
        c.vignette(0.4)
        c.host(x: rtl ? 600 : 1800, floor: 1570, height: 1440)
        typeBlock(c, lproj: lproj, lines: lines, edge: rtl ? 2400 - 130 : 130, top: 250, width: 1150, scale: 0.85, rtl: rtl)
        c.write(folder.appendingPathComponent("search.png"))
    }
    print("\(locale): header.png, search.png")
}
