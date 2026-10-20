import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreText

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: CGFloat(S)); ctx.scaleBy(x: 1, y: -1)
func c(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, 1])!
}
let orange = c(0xF47B3A), paper = c(0xFCFBF7), white = c(0xFFFFFF)
ctx.setFillColor(paper); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))

func rr(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }

ctx.saveGState()
ctx.translateBy(x: 512, y: 512); ctx.scaleBy(x: 0.88, y: 0.88); ctx.translateBy(x: -545, y: -550)
ctx.saveGState()
ctx.translateBy(x: 410, y: 560); ctx.rotate(by: -0.30)
let body = CGRect(x: -215, y: -345, width: 430, height: 690)
ctx.addPath(rr(body, 100)); ctx.setFillColor(orange); ctx.fillPath()
let screen = CGRect(x: -165, y: -230, width: 330, height: 520)
ctx.addPath(rr(screen, 58)); ctx.setFillColor(white); ctx.fillPath()
ctx.addPath(rr(CGRect(x: -52, y: -292, width: 104, height: 26), 13)); ctx.setFillColor(white); ctx.fillPath()
// speech bubble
let bubble = CGMutablePath()
bubble.addPath(rr(CGRect(x: -105, y: -85, width: 210, height: 150), 44))
ctx.addPath(bubble); ctx.setFillColor(orange); ctx.fillPath()
let tail = CGMutablePath()
tail.move(to: CGPoint(x: -85, y: 30)); tail.addLine(to: CGPoint(x: -88, y: 118)); tail.addLine(to: CGPoint(x: -5, y: 55)); tail.closeSubpath()
ctx.addPath(tail); ctx.fillPath()
ctx.setFillColor(white)
for x in [-56.0, 0.0, 56.0] { ctx.fillEllipse(in: CGRect(x: x - 19, y: -28, width: 38, height: 38)) }
ctx.restoreGState()

// Sound arcs
ctx.setStrokeColor(orange); ctx.setLineCap(.round); ctx.setLineWidth(46)
let origin = CGPoint(x: 700, y: 540)
for (r, a0, a1) in [(140.0, -58.0, 32.0), (250.0, -58.0, 32.0)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.addArc(center: origin, radius: r, startAngle: a0 * .pi / 180, endAngle: a1 * .pi / 180, clockwise: false)
    ctx.strokePath()
}
// "Hey!" at the bottom-right (drawn in plain icon space, outside the scaled group)
ctx.restoreGState()
ctx.saveGState()
let font = CTFontCreateWithName("ArialRoundedMTBold" as CFString, 150, nil)
let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): orange, NSAttributedString.Key(kCTKernAttributeName as String): -2]
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Hey!", attributes: attrs))
let bounds = CTLineGetBoundsWithOptions(line, [])
ctx.translateBy(x: 950 - bounds.width, y: 905)      // right edge x=950, baseline y=905
ctx.scaleBy(x: 1, y: -1)                             // undo the top-left flip for text
ctx.textPosition = .zero
CTLineDraw(line, ctx)
ctx.restoreGState()
let out = CommandLine.arguments[1]
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
