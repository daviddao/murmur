// Generates AppIcon.icns: a dark squircle with a white waveform.
// Usage: swift scripts/make_icon.swift <output-dir>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build"
let outURL = URL(fileURLWithPath: outDir)
let iconsetURL = outURL.appendingPathComponent("Murmur.iconset")
try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func render(_ pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let s = size / 1024.0
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Big Sur style squircle body.
    let inset = 100 * s
    let body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(
        colors: [
            NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.21, alpha: 1),
            NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1),
        ]
    )!.draw(in: path, angle: -90)

    // Waveform bars.
    let ratios: [CGFloat] = [0.34, 0.62, 0.86, 1.0, 0.86, 0.62, 0.34]
    let barWidth = 56 * s
    let gap = 44 * s
    let maxHeight = 430 * s
    let totalWidth = CGFloat(ratios.count) * barWidth + CGFloat(ratios.count - 1) * gap
    var x = (size - totalWidth) / 2
    NSColor.white.withAlphaComponent(0.95).setFill()
    for ratio in ratios {
        let height = maxHeight * ratio
        let bar = NSRect(x: x, y: (size - height) / 2, width: barWidth, height: height)
        NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        x += barWidth + gap
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let specs: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs {
    try render(px).write(to: iconsetURL.appendingPathComponent("\(name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "-c", "icns", iconsetURL.path,
    "-o", outURL.appendingPathComponent("AppIcon.icns").path,
]
try iconutil.run()
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
