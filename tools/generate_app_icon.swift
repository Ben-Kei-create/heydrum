import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: CGFloat(S)); ctx.scaleBy(x: 1, y: -1)   // top-left origin

func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}
func linear(_ colors: [CGColor], _ locs: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)! }
func radial(_ ctx: CGContext, _ center: CGPoint, _ r: CGFloat, _ colors: [CGColor], _ locs: [CGFloat]) {
    ctx.drawRadialGradient(linear(colors, locs), startCenter: center, startRadius: 0, endCenter: center, endRadius: r, options: [])
}

// Background: warm paper → soft beige, with glows so the glass has something to pick up.
ctx.drawLinearGradient(linear([c(0xFFFBF5), c(0xF6E7D6), c(0xEBD5BC)], [0, 0.55, 1]), start: CGPoint(x: 0, y: 0), end: CGPoint(x: S, y: S), options: [])
radial(ctx, CGPoint(x: 760, y: 700), 520, [c(0xED8D45, 0.55), c(0xED8D45, 0)], [0, 1])
radial(ctx, CGPoint(x: 220, y: 260), 480, [c(0xFFFFFF, 0.9), c(0xFFFFFF, 0)], [0, 1])
radial(ctx, CGPoint(x: 330, y: 820), 380, [c(0xE9C9A3, 0.7), c(0xE9C9A3, 0)], [0, 1])

struct Disc { let center: CGPoint; let r: CGFloat; let tint: UInt32; let tintA: CGFloat }
let left = Disc(center: CGPoint(x: 392, y: 520), r: 262, tint: 0xE8D2B4, tintA: 0.62)
let right = Disc(center: CGPoint(x: 632, y: 504), r: 262, tint: 0xED8D45, tintA: 0.78)

func circle(_ d: Disc, inset: CGFloat = 0) -> CGPath {
    CGPath(ellipseIn: CGRect(x: d.center.x - d.r + inset, y: d.center.y - d.r + inset, width: 2 * (d.r - inset), height: 2 * (d.r - inset)), transform: nil)
}

func glass(_ d: Disc) {
    // drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -30), blur: 55, color: c(0x8A4A1C, 0.26))
    ctx.addPath(circle(d)); ctx.setFillColor(c(d.tint, 0.9)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(circle(d)); ctx.clip()
    let top = CGPoint(x: d.center.x - d.r * 0.6, y: d.center.y - d.r)
    let bottom = CGPoint(x: d.center.x + d.r * 0.5, y: d.center.y + d.r)
    // body
    ctx.drawLinearGradient(linear([c(0xFFFFFF, 0.55), c(d.tint, d.tintA), c(d.tint, d.tintA * 0.9)], [0, 0.42, 1]), start: top, end: bottom, options: [])
    // depth: darker toward lower-right edge, bright rim light
    radial(ctx, CGPoint(x: d.center.x - d.r * 0.25, y: d.center.y - d.r * 0.3), d.r * 1.35,
           [c(0xFFFFFF, 0.0), c(0xFFFFFF, 0.0), c(0x7A3B10, 0.16)], [0, 0.62, 1])
    radial(ctx, d.center, d.r, [c(0xFFFFFF, 0), c(0xFFFFFF, 0), c(0xFFFFFF, 0.42)], [0, 0.78, 1])
    // specular highlight (top-left)
    ctx.saveGState()
    ctx.translateBy(x: d.center.x - d.r * 0.34, y: d.center.y - d.r * 0.5); ctx.rotate(by: -0.62)
    let hl = CGRect(x: -d.r * 0.5, y: -d.r * 0.16, width: d.r, height: d.r * 0.32)
    ctx.addPath(CGPath(ellipseIn: hl, transform: nil)); ctx.clip()
    ctx.drawLinearGradient(linear([c(0xFFFFFF, 0.85), c(0xFFFFFF, 0.0)], [0, 1]), start: CGPoint(x: 0, y: hl.minY), end: CGPoint(x: 0, y: hl.maxY), options: [])
    ctx.restoreGState()
    // caustic glow bottom-right
    radial(ctx, CGPoint(x: d.center.x + d.r * 0.42, y: d.center.y + d.r * 0.62), d.r * 0.55, [c(0xFFFFFF, 0.34), c(0xFFFFFF, 0)], [0, 1])
    ctx.restoreGState()
    // rim (gradient ring)
    ctx.saveGState()
    let ring = CGMutablePath(); ring.addPath(circle(d)); ring.addPath(circle(d, inset: 5))
    ctx.addPath(ring); ctx.clip(using: .evenOdd)
    ctx.drawLinearGradient(linear([c(0xFFFFFF, 0.95), c(0xFFFFFF, 0.25), c(0xFFFFFF, 0.65)], [0, 0.55, 1]),
                           start: CGPoint(x: d.center.x - d.r, y: d.center.y - d.r), end: CGPoint(x: d.center.x + d.r, y: d.center.y + d.r), options: [])
    ctx.restoreGState()
}

glass(left)
glass(right)

// Overlap lens: where the two glass layers stack
ctx.saveGState()
ctx.addPath(circle(left)); ctx.clip()
ctx.addPath(circle(right)); ctx.clip()
ctx.drawLinearGradient(linear([c(0xFFFFFF, 0.55), c(0xFFF3E4, 0.22), c(0xFFFFFF, 0.38)], [0, 0.5, 1]), start: CGPoint(x: 512, y: 260), end: CGPoint(x: 512, y: 770), options: [])
ctx.restoreGState()
ctx.saveGState()
let lens = CGMutablePath(); lens.addPath(circle(left)); lens.addPath(circle(right))
ctx.addPath(circle(left)); ctx.clip()
ctx.setStrokeColor(c(0xFFFFFF, 0.8)); ctx.setLineWidth(3)
ctx.addPath(circle(right)); ctx.strokePath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(circle(right)); ctx.clip()
ctx.setStrokeColor(c(0xFFFFFF, 0.8)); ctx.setLineWidth(3)
ctx.addPath(circle(left)); ctx.strokePath()
ctx.restoreGState()

let out = CommandLine.arguments[1]
let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote", out)
