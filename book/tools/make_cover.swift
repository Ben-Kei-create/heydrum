import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Kindle cover 1600 x 2560 (ratio 1:1.6), JPEG. Drawn with CoreGraphics only (no AI-generated imagery).
let W = 1600, H = 2560
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}
let g = CGGradient(colorsSpace: cs, colors: [c(0xFFFBF5), c(0xF6E7D6)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: CGFloat(W), y: 0), options: [])

// top orange block
ctx.setFillColor(c(0xED8D45)); ctx.fill(CGRect(x: 0, y: CGFloat(H) - 520, width: CGFloat(W), height: 520))
ctx.setFillColor(c(0xD8752C)); ctx.fill(CGRect(x: 0, y: CGFloat(H) - 540, width: CGFloat(W), height: 20))

func draw(_ text: String, size: CGFloat, font: String, color: UInt32, centerX: CGFloat, baseline: CGFloat) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): f,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): c(color)]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    let b = CTLineGetBoundsWithOptions(line, [])
    ctx.textPosition = CGPoint(x: centerX - b.width / 2 - b.minX, y: baseline)
    CTLineDraw(line, ctx)
}

let cx = CGFloat(W) / 2
draw("APP STORE", size: 96, font: "HiraginoSans-W6", color: 0x302C29, centerX: cx, baseline: CGFloat(H) - 250)
draw("申請 ガイドブック", size: 84, font: "HiraginoSans-W3", color: 0x302C29, centerX: cx, baseline: CGFloat(H) - 390)

// Title (3 lines)
draw("個人開発者のための", size: 128, font: "HiraginoSans-W7", color: 0x302C29, centerX: cx, baseline: CGFloat(H) - 900)
draw("App Store 申請", size: 168, font: "HiraginoSans-W7", color: 0x302C29, centerX: cx, baseline: CGFloat(H) - 1120)
draw("ハンズオン", size: 190, font: "HiraginoSans-W7", color: 0xD8752C, centerX: cx, baseline: CGFloat(H) - 1360)

// check mark in a circle
let center = CGPoint(x: cx, y: CGFloat(H) - 1700)
ctx.setFillColor(c(0xED8D45)); ctx.fillEllipse(in: CGRect(x: center.x - 170, y: center.y - 170, width: 340, height: 340))
ctx.setStrokeColor(c(0x302C29)); ctx.setLineWidth(46); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: center.x - 85, y: center.y - 5)); ctx.addLine(to: CGPoint(x: center.x - 25, y: center.y - 70)); ctx.addLine(to: CGPoint(x: center.x + 95, y: center.y + 75))
ctx.strokePath()

draw("契約・ビルド・提出・却下対応まで", size: 70, font: "HiraginoSans-W6", color: 0x302C29, centerX: cx, baseline: 430)
draw("実際にやった順番で。AIに投げる依頼文つき", size: 56, font: "HiraginoSans-W3", color: 0x756F69, centerX: cx, baseline: 335)
let author = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "著者名"
draw(author, size: 84, font: "HiraginoSans-W6", color: 0x302C29, centerX: cx, baseline: 150)

let out = CommandLine.arguments[1]
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.jpeg.identifier as CFString, 1, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
