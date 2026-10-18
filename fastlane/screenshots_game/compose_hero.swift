// Composes the first App Store screenshot for every locale of Dubloon the Game: the stage, the
// host, the game's logo, its subtitle and three lines of copy, in each language's own font
// (the same mapping as `GameFont` in the app). Core Text does the shaping, so Arabic and Thai
// come out joined and right-to-left where they should.
//
//   swift fastlane/screenshots_game/compose_hero.swift
//
// Reads hero_lines.json and the subtitle from each locale's Game.strings; writes
// <locale>/00_hero.png at 1320x2868.

import AppKit
import CoreText

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let repo = root.deletingLastPathComponent().deletingLastPathComponent()
let size = CGSize(width: 1320, height: 2868)

let navy = NSColor(srgbRed: 0.047, green: 0.133, blue: 0.200, alpha: 1)
let ivory = NSColor(srgbRed: 0.984, green: 0.965, blue: 0.918, alpha: 1)
let cyan = NSColor(srgbRed: 0.373, green: 0.827, blue: 0.953, alpha: 1)
let gold = NSColor(srgbRed: 1.0, green: 0.784, blue: 0.239, alpha: 1)

for name in ["LilitaOne-Regular", "MPLUSRounded1c-Black"] {
    let url = repo.appendingPathComponent("DubloonGame/Resources/Fonts/\(name).ttf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

func font(for lproj: String, size: CGFloat) -> NSFont {
    let lilita = ["en", "de", "es", "fr", "it", "nl", "da", "sv", "nb", "fi", "pt-PT"]
    if lilita.contains(lproj) { return NSFont(name: "LilitaOne", size: size)! }
    if lproj == "ar" { return NSFont(name: ".SFArabicRounded-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .black) }
    if lproj == "th" { return NSFont(name: "Thonburi-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .black) }
    return NSFont(name: "RoundedMplus1c-Black", size: size)!
}

func subtitle(_ lproj: String) -> String {
    let path = repo.appendingPathComponent("DubloonGame/Resources/\(lproj).lproj/Game.strings")
    let dict = NSDictionary(contentsOf: path) as? [String: String]
    return dict?["game.subtitle"] ?? "The Game"
}

/// One line, centred at `centerY` (from the top), outlined in navy with a lip under it like the
/// game's lettering, shrunk until it fits `maxWidth`.
func drawLine(_ text: String, lproj: String, size pointSize: CGFloat, color: NSColor, centerY: CGFloat, maxWidth: CGFloat) {
    var points = pointSize
    var attributed: NSAttributedString
    repeat {
        attributed = NSAttributedString(string: text, attributes: [.font: font(for: lproj, size: points)])
        if attributed.size().width <= maxWidth { break }
        points -= 2
    } while points > pointSize * 0.5

    let f = font(for: lproj, size: points)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.baseWritingDirection = lproj == "ar" ? .rightToLeft : .natural
    let measured = NSAttributedString(string: text, attributes: [.font: f, .paragraphStyle: paragraph]).size()
    let stroke = points * 0.16
    let lip = points * 0.07
    // AppKit's origin is the bottom left.
    let rect = CGRect(x: 0, y: size.height - centerY - measured.height / 2, width: size.width, height: measured.height)

    func draw(_ color: NSColor, strokeWidth: CGFloat?, offset: CGFloat) {
        var attributes: [NSAttributedString.Key: Any] = [.font: f, .paragraphStyle: paragraph, .foregroundColor: color]
        if let strokeWidth {
            attributes[.strokeColor] = navy
            attributes[.strokeWidth] = strokeWidth / points * 100
        }
        NSAttributedString(string: text, attributes: attributes).draw(in: rect.offsetBy(dx: 0, dy: -offset))
    }
    draw(navy, strokeWidth: stroke * 2, offset: lip)
    draw(navy, strokeWidth: nil, offset: lip)
    draw(navy, strokeWidth: stroke * 2, offset: 0)
    draw(color, strokeWidth: nil, offset: 0)
}

func image(_ path: String) -> NSImage { NSImage(contentsOf: repo.appendingPathComponent(path))! }

let stage = image("DubloonGame/Assets.xcassets/game-stage.imageset/stage_background.png")
let host = image("DubloonGame/Assets.xcassets/Host.spriteatlas/game-host-delight.imageset/game-host-delight@3x.png")
let logo = image("DesignAssets/game-logo/dubloon-game-logo.png")

let data = try! Data(contentsOf: root.appendingPathComponent("hero_lines.json"))
let locales = try! JSONSerialization.jsonObject(with: data) as! [String: [String: Any]]

for (locale, entry) in locales.sorted(by: { $0.key < $1.key }) {
    let lproj = entry["lproj"] as! String
    let lines = entry["lines"] as! [String]

    // Opaque, because the App Store refuses screenshots with an alpha channel.
    let cg = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

    // The stage, filling the frame, darkening towards the top where the words are.
    let scale = max(size.width / stage.size.width, size.height / stage.size.height)
    let drawn = CGSize(width: stage.size.width * scale, height: stage.size.height * scale)
    stage.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
    NSGradient(colors: [navy.withAlphaComponent(0.92), navy.withAlphaComponent(0)])!
        .draw(in: CGRect(x: 0, y: size.height * 0.45, width: size.width, height: size.height * 0.55), angle: -90)

    // The host, from the bottom, cropped at the knees by the frame.
    let hostHeight: CGFloat = 2000
    let hostWidth = hostHeight * host.size.width / host.size.height
    host.draw(in: CGRect(x: (size.width - hostWidth) / 2, y: size.height - 1080 - hostHeight, width: hostWidth, height: hostHeight))

    let logoWidth: CGFloat = 1000
    let logoHeight = logoWidth * logo.size.height / logo.size.width
    logo.draw(in: CGRect(x: (size.width - logoWidth) / 2, y: size.height - 110 - logoHeight, width: logoWidth, height: logoHeight))

    drawLine(subtitle(lproj).uppercased(), lproj: lproj, size: 76, color: cyan, centerY: 470, maxWidth: 1000)
    drawLine(lines[0], lproj: lproj, size: 140, color: ivory, centerY: 640, maxWidth: 1220)
    drawLine(lines[1], lproj: lproj, size: 140, color: cyan, centerY: 800, maxWidth: 1220)
    drawLine(lines[2], lproj: lproj, size: 160, color: gold, centerY: 965, maxWidth: 1220)

    NSGraphicsContext.restoreGraphicsState()

    let folder = root.appendingPathComponent(locale)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let png = NSBitmapImageRep(cgImage: cg.makeImage()!).representation(using: .png, properties: [:])!
    try! png.write(to: folder.appendingPathComponent("00_hero.png"))
    print("\(locale): 00_hero.png")
}
