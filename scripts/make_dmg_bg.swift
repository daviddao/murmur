// Generates the DMG window background (1x + 2x PNG).
// Usage: swift scripts/make_dmg_bg.swift <output-dir>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build"
let logicalWidth: CGFloat = 660
let logicalHeight: CGFloat = 400

func render(scale: CGFloat) -> Data {
    let w = Int(logicalWidth * scale), h = Int(logicalHeight * scale)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    // Background gradient.
    NSGradient(
        colors: [
            NSColor(calibratedRed: 0.085, green: 0.085, blue: 0.11, alpha: 1),
            NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.045, alpha: 1),
        ]
    )!.draw(in: NSRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight), angle: -90)

    // Small waveform wordmark, top center. (y measured from bottom)
    let ratios: [CGFloat] = [0.45, 0.75, 1.0, 0.75, 0.45]
    let barW: CGFloat = 5, gap: CGFloat = 4, maxH: CGFloat = 26
    let waveWidth = CGFloat(ratios.count) * barW + CGFloat(ratios.count - 1) * gap
    var x = (logicalWidth - waveWidth) / 2
    let waveCenterY: CGFloat = 348
    NSColor.white.withAlphaComponent(0.9).setFill()
    for r in ratios {
        let bh = maxH * r
        NSBezierPath(
            roundedRect: NSRect(x: x, y: waveCenterY - bh / 2, width: barW, height: bh),
            xRadius: barW / 2, yRadius: barW / 2
        ).fill()
        x += barW + gap
    }

    func drawCentered(_ s: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, kern: CGFloat = 0) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
            .kern: kern,
        ]
        let t = NSAttributedString(string: s, attributes: attrs)
        t.draw(at: NSPoint(x: (logicalWidth - t.size().width) / 2, y: y))
    }

    drawCentered("Murmur", y: 298, size: 21, weight: .semibold, alpha: 0.92, kern: -0.3)

    // Arrow between the two icon slots (icons sit at top-based y=195 → draw y≈205).
    let arrowY: CGFloat = 205
    let startX: CGFloat = 248, endX: CGFloat = 408
    let arrow = NSBezierPath()
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: startX, y: arrowY))
    arrow.line(to: NSPoint(x: endX, y: arrowY))
    arrow.move(to: NSPoint(x: endX - 14, y: arrowY + 11))
    arrow.line(to: NSPoint(x: endX, y: arrowY))
    arrow.line(to: NSPoint(x: endX - 14, y: arrowY - 11))
    NSColor.white.withAlphaComponent(0.35).setStroke()
    arrow.stroke()

    drawCentered("Drag Murmur into Applications to install", y: 42, size: 13, weight: .regular, alpha: 0.4)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try render(scale: 1).write(to: URL(fileURLWithPath: "\(outDir)/dmg-bg.png"))
try render(scale: 2).write(to: URL(fileURLWithPath: "\(outDir)/dmg-bg@2x.png"))
print("wrote \(outDir)/dmg-bg.png + @2x")
