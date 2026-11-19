import AppKit
import Foundation

let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? "build/AppIcon.iconset",
    isDirectory: true
)
try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

func fillRoundedRect(
    _ rect: NSRect,
    radius: CGFloat,
    color: NSColor
) {
    color.setFill()
    NSBezierPath(
        roundedRect: rect,
        xRadius: radius,
        yRadius: radius
    ).fill()
}

func renderIcon(pixelSize: Int) -> Data? {
    let size = CGFloat(pixelSize)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return nil
    }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    defer { NSGraphicsContext.restoreGraphicsState() }

    let context = graphicsContext.cgContext
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let outerRect = NSRect(
        x: size * 0.055,
        y: size * 0.055,
        width: size * 0.89,
        height: size * 0.89
    )
    fillRoundedRect(
        outerRect,
        radius: size * 0.22,
        color: .systemBlue
    )

    let pageRect = NSRect(
        x: size * 0.215,
        y: size * 0.185,
        width: size * 0.57,
        height: size * 0.62
    )
    let pageRadius = size * 0.095
    fillRoundedRect(pageRect, radius: pageRadius, color: .white)

    let tabWidth = size * 0.072
    let tabHeight = size * 0.17
    for centerX in [0.345, 0.655] {
        fillRoundedRect(
            NSRect(
                x: size * centerX - tabWidth / 2,
                y: pageRect.maxY - tabHeight * 0.50,
                width: tabWidth,
                height: tabHeight
            ),
            radius: tabWidth / 2,
            color: .white
        )
    }

    let headerHeight = pageRect.height * 0.24
    let headerRect = NSRect(
        x: pageRect.minX,
        y: pageRect.maxY - headerHeight,
        width: pageRect.width,
        height: headerHeight
    )
    let headerPath = NSBezierPath(
        roundedRect: headerRect,
        xRadius: pageRadius,
        yRadius: pageRadius
    )
    NSColor.systemBlue.withAlphaComponent(0.18).setFill()
    headerPath.fill()

    if pixelSize <= 32 {
        fillRoundedRect(
            NSRect(
                x: size * 0.305,
                y: size * 0.365,
                width: size * 0.39,
                height: size * 0.105
            ),
            radius: size * 0.052,
            color: .systemBlue
        )
    } else {
        let bars: [
            (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
             alpha: CGFloat)
        ] = [
            (0.295, 0.475, 0.33, 0.065, 0.92),
            (0.295, 0.382, 0.41, 0.050, 0.24),
            (0.295, 0.300, 0.245, 0.050, 0.24)
        ]

        for bar in bars {
            fillRoundedRect(
                NSRect(
                    x: size * bar.x,
                    y: size * bar.y,
                    width: size * bar.width,
                    height: size * bar.height
                ),
                radius: size * bar.height / 2,
                color: .systemBlue.withAlphaComponent(bar.alpha)
            )
        }
    }

    return bitmap.representation(using: .png, properties: [:])
}

let files: [(String, Int)] = [
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

for (name, size) in files {
    guard let data = renderIcon(pixelSize: size) else {
        fputs("Unable to render \(name)\n", stderr)
        exit(1)
    }
    try data.write(to: outputDirectory.appendingPathComponent(name))
}
