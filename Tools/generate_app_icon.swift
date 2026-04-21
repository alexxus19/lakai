import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: generate_app_icon.swift <appiconset_path>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let fileManager = FileManager.default

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (fileName, size) in iconSizes {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("Failed to allocate bitmap for \(fileName)\n", stderr)
        exit(2)
    }

    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fputs("Failed to create graphics context for \(fileName)\n", stderr)
        exit(2)
    }

    NSGraphicsContext.current = graphicsContext

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.76, green: 0.89, blue: 0.97, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.40, blue: 0.62, alpha: 1)
    ])!
    gradient.draw(in: backgroundPath, angle: 292)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.shadowBlurRadius = size * 0.05
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
    shadow.set()

    let slateRect = NSRect(x: size * 0.16, y: size * 0.19, width: size * 0.68, height: size * 0.62)
    let slatePath = NSBezierPath(roundedRect: slateRect, xRadius: size * 0.14, yRadius: size * 0.14)
    NSColor(calibratedRed: 0.11, green: 0.17, blue: 0.24, alpha: 1).setFill()
    slatePath.fill()

    let cardRect = NSRect(x: size * 0.22, y: size * 0.26, width: size * 0.56, height: size * 0.48)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: size * 0.08, yRadius: size * 0.08)
    NSColor(calibratedRed: 0.95, green: 0.98, blue: 1.00, alpha: 1).setFill()
    cardPath.fill()

    let frameRect = NSRect(x: cardRect.maxX - size * 0.16, y: cardRect.minY, width: size * 0.16, height: cardRect.height)
    let framePath = NSBezierPath(roundedRect: frameRect, xRadius: size * 0.06, yRadius: size * 0.06)
    NSColor(calibratedRed: 0.23, green: 0.58, blue: 0.78, alpha: 1).setFill()
    framePath.fill()

    NSColor(calibratedRed: 0.18, green: 0.26, blue: 0.34, alpha: 0.92).setFill()
    NSBezierPath(roundedRect: NSRect(x: cardRect.minX + size * 0.05, y: cardRect.maxY - size * 0.12, width: size * 0.18, height: size * 0.07), xRadius: size * 0.03, yRadius: size * 0.03).fill()

    let lineColor = NSColor(calibratedRed: 0.45, green: 0.56, blue: 0.65, alpha: 0.95)
    for offset in [0.12, 0.20, 0.28] {
        let line = NSBezierPath(roundedRect: NSRect(x: cardRect.minX + size * 0.05, y: cardRect.maxY - size * CGFloat(offset), width: size * 0.28, height: size * 0.022), xRadius: size * 0.011, yRadius: size * 0.011)
        lineColor.setFill()
        line.fill()
    }

    let badgeRect = NSRect(x: size * 0.10, y: size * 0.70, width: size * 0.22, height: size * 0.15)
    let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: size * 0.07, yRadius: size * 0.07)
    NSColor(calibratedRed: 0.95, green: 0.98, blue: 1.00, alpha: 0.95).setFill()
    badgePath.fill()

    let badgeText = NSAttributedString(
        string: "L",
        attributes: [
            .font: NSFont.systemFont(ofSize: size * 0.11, weight: .black),
            .foregroundColor: NSColor(calibratedRed: 0.11, green: 0.17, blue: 0.24, alpha: 1)
        ]
    )
    let badgeSize = badgeText.size()
    badgeText.draw(at: NSPoint(x: badgeRect.midX - badgeSize.width / 2, y: badgeRect.midY - badgeSize.height / 2))

    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to generate icon file \(fileName)\n", stderr)
        exit(2)
    }

    try pngData.write(to: outputDirectory.appendingPathComponent(fileName), options: .atomic)
}

print("Generated \(iconSizes.count) icon files in \(outputDirectory.path)")