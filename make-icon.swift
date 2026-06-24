#!/usr/bin/env swift
// Generates AppIcon.icns: a two-way swap glyph on a deep gradient.
import AppKit

func drawIcon(px: Int) -> Data {
    let size = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Rounded background with diagonal gradient.
    let radius = size * 0.2237
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    cg.clip()
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [CGColor(red: 0.16, green: 0.13, blue: 0.10, alpha: 1),
                 CGColor(red: 0.06, green: 0.05, blue: 0.08, alpha: 1)] as CFArray,
        locations: [0, 1])!
    cg.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    let accent = CGColor(red: 1.00, green: 0.62, blue: 0.30, alpha: 1)
    cg.setShadow(offset: .zero, blur: size * 0.04, color: accent.copy(alpha: 0.6))

    // Two opposing arrows (a swap glyph).
    let lw = size * 0.07
    let head = size * 0.11
    let inset = size * 0.26
    let gap = size * 0.085

    // Top arrow: points right.
    drawArrow(cg, accent: accent, lineWidth: lw, headSize: head,
              from: CGPoint(x: inset, y: size * 0.5 + gap),
              to: CGPoint(x: size - inset, y: size * 0.5 + gap),
              pointingRight: true)
    // Bottom arrow: points left.
    drawArrow(cg, accent: accent, lineWidth: lw, headSize: head,
              from: CGPoint(x: size - inset, y: size * 0.5 - gap),
              to: CGPoint(x: inset, y: size * 0.5 - gap),
              pointingRight: false)

    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func drawArrow(_ cg: CGContext, accent: CGColor, lineWidth: CGFloat, headSize: CGFloat,
               from: CGPoint, to: CGPoint, pointingRight: Bool) {
    cg.setStrokeColor(accent)
    cg.setFillColor(accent)
    cg.setLineWidth(lineWidth)
    cg.setLineCap(.round)

    // Shaft (stop short so the head sits at the tip).
    let tipPullback = pointingRight ? -headSize * 0.6 : headSize * 0.6
    cg.move(to: from)
    cg.addLine(to: CGPoint(x: to.x + tipPullback, y: to.y))
    cg.strokePath()

    // Head (filled triangle).
    let dir: CGFloat = pointingRight ? 1 : -1
    let tip = CGPoint(x: to.x, y: to.y)
    cg.move(to: tip)
    cg.addLine(to: CGPoint(x: tip.x - dir * headSize, y: tip.y + headSize * 0.72))
    cg.addLine(to: CGPoint(x: tip.x - dir * headSize, y: tip.y - headSize * 0.72))
    cg.closePath()
    cg.fillPath()
}

let fm = FileManager.default
let iconset = "GitSwitch.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs {
    let data = drawIcon(px: px)
    try! data.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
print("Wrote \(iconset). Run: iconutil -c icns \(iconset) -o AppIcon.icns")
