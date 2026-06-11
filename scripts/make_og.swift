// Generates site/og.png (1200x630 Open Graph image).
// Usage: swift scripts/make_og.swift site/og.png
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "site/og.png"
let width = 1200, height = 630

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let size = NSSize(width: width, height: height)

// Background gradient.
NSGradient(
    colors: [
        NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.13, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.05, alpha: 1),
    ]
)!.draw(in: NSRect(origin: .zero, size: size), angle: -90)

// Waveform bars, centered upper area.
let ratios: [CGFloat] = [0.30, 0.52, 0.74, 1.0, 0.74, 0.52, 0.30]
let barWidth: CGFloat = 26
let gap: CGFloat = 20
let maxHeight: CGFloat = 190
let totalWidth = CGFloat(ratios.count) * barWidth + CGFloat(ratios.count - 1) * gap
var x = (CGFloat(width) - totalWidth) / 2
let centerY: CGFloat = 415
NSColor.white.withAlphaComponent(0.95).setFill()
for ratio in ratios {
    let h = maxHeight * ratio
    let bar = NSRect(x: x, y: centerY - h / 2, width: barWidth, height: h)
    NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    x += barWidth + gap
}

// Title.
func drawCentered(_ string: String, y: CGFloat, font: NSFont, color: NSColor, kern: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: kern]
    let attributed = NSAttributedString(string: string, attributes: attrs)
    let textSize = attributed.size()
    attributed.draw(at: NSPoint(x: (CGFloat(width) - textSize.width) / 2, y: y))
}

drawCentered(
    "Murmur",
    y: 175,
    font: NSFont.systemFont(ofSize: 84, weight: .bold),
    color: .white,
    kern: -1.5
)
drawCentered(
    "Hold right ⌘ · speak · release — it types.",
    y: 110,
    font: NSFont.systemFont(ofSize: 34, weight: .medium),
    color: NSColor.white.withAlphaComponent(0.6)
)
drawCentered(
    "Open-source local dictation for macOS",
    y: 55,
    font: NSFont.systemFont(ofSize: 26, weight: .regular),
    color: NSColor.white.withAlphaComponent(0.35)
)

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
