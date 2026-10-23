import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, 1])!
}
let inDir = CommandLine.arguments[1], outDir = CommandLine.arguments[2]
let jobs: [(String, String, String)] = [
    ("05-reading", "01", "遠くの人にも届く\n大きな文字で読み上げ"),
    ("03-voice", "02", "読み上げの\n開始タイミングを選べる"),
    ("04-countdown", "03", "カウントダウンで\n心の準備もOK"),
    ("02-drum", "04", "ボタンをタップするだけで\n音が鳴る"),
    ("06-history", "05", "履歴からワンタップで\nもう一度再生"),
    ("07-settings", "06", "音量・声・速さを\nお好みに調整"),
    ("01-home", "07", "音を鳴らす。\n文字を読み上げる。"),
]
let firstSrc = CGImageSourceCreateWithURL(URL(fileURLWithPath: "\(inDir)/05-reading.png") as CFURL, nil)!
let firstImg = CGImageSourceCreateImageAtIndex(firstSrc, 0, nil)!
let W = firstImg.width, H = firstImg.height
let k = CGFloat(W) / 1320
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (name, order, caption) in jobs {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: "\(inDir)/\(name).png") as CFURL, nil)!
    let shot = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let grad = CGGradient(colorsSpace: cs, colors: [color(0xFFFBF5), color(0xF6E7D6)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])
    // caption (CG origin is bottom-left)
    let font = CTFontCreateWithName("HiraginoSans-W7" as CFString, 104 * k, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(0x302C29)]
    var baseline = CGFloat(H) - 230 * k
    for lineText in caption.split(separator: "\n") {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(lineText), attributes: attrs))
        let b = CTLineGetBoundsWithOptions(line, [])
        ctx.textPosition = CGPoint(x: (CGFloat(W) - b.width) / 2 - b.minX, y: baseline)
        CTLineDraw(line, ctx)
        baseline -= 140 * k
    }
    // screenshot with rounded corners + shadow
    let w: CGFloat = 1010 * k, h = w * CGFloat(shot.height) / CGFloat(shot.width)
    let rect = CGRect(x: (CGFloat(W) - w) / 2, y: CGFloat(H) - 500 * k - h, width: w, height: h)
    let rr = CGPath(roundedRect: rect, cornerWidth: 96 * k, cornerHeight: 96 * k, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -30 * k), blur: 70 * k, color: CGColor(colorSpace: cs, components: [0.35, 0.2, 0.05, 0.28])!)
    ctx.addPath(rr); ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(rr); ctx.clip(); ctx.draw(shot, in: rect); ctx.restoreGState()
    ctx.addPath(rr); ctx.setStrokeColor(color(0xDDD7D0)); ctx.setLineWidth(4 * k); ctx.strokePath()
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/\(order)-\(name.dropFirst(3)).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
}
print("done")
