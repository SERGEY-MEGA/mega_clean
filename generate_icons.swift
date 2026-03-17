import Foundation
import AppKit

struct IconSpec {
    let name: String          // base name (no extension)
    let symbolName: String
    let primary: NSColor
    let secondary: NSColor
}

let specs: [IconSpec] = [
    IconSpec(name: "AppIcon", symbolName: "sparkles", primary: NSColor.systemBlue, secondary: NSColor.systemTeal),
    IconSpec(name: "MiniIcon", symbolName: "sparkles", primary: NSColor.systemGreen, secondary: NSColor.systemBlue),
]

let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

func ensureDir(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func roundedRectPath(in rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func renderIconPNG(to url: URL, size: Int, spec: IconSpec) throws {
    let px = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: px, height: px)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(px),
        pixelsHigh: Int(px),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bitmap rep creation failed"])
    }
    rep.size = rect.size

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Graphics context creation failed"])
    }
    let prev = NSGraphicsContext.current
    NSGraphicsContext.current = ctx
    defer { NSGraphicsContext.current = prev }

    // Background: subtle gradient + rounded corners
    let bg = roundedRectPath(in: rect.insetBy(dx: px * 0.03, dy: px * 0.03), radius: px * 0.22)
    let grad = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.98),
        NSColor(calibratedWhite: 0.93, alpha: 1.0),
    ])!
    grad.draw(in: bg, angle: 90)

    // Soft border
    NSColor(calibratedWhite: 0.80, alpha: 0.35).setStroke()
    bg.lineWidth = max(1, px * 0.008)
    bg.stroke()

    // Symbol in center
    guard let symbol = NSImage(systemSymbolName: spec.symbolName, accessibilityDescription: nil) else {
        throw NSError(domain: "icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "SF Symbol not found: \(spec.symbolName)"])
    }

    let symbolRect = rect.insetBy(dx: px * 0.23, dy: px * 0.23)
    let config = NSImage.SymbolConfiguration(pointSize: symbolRect.width, weight: .bold)
    let configured = symbol.withSymbolConfiguration(config) ?? symbol

    // Two-tone: draw a shadow-ish back layer then front layer
    let shadowOffset = CGSize(width: px * 0.02, height: -px * 0.02)
    let shadowRect = symbolRect.offsetBy(dx: shadowOffset.width, dy: shadowOffset.height)

    let back = configured.copy() as! NSImage
    back.isTemplate = true
    spec.secondary.withAlphaComponent(0.35).set()
    back.draw(in: shadowRect, from: .zero, operation: .sourceAtop, fraction: 1.0)

    let front = configured.copy() as! NSImage
    front.isTemplate = true
    spec.primary.set()
    front.draw(in: symbolRect, from: .zero, operation: .sourceAtop, fraction: 1.0)

    // Export
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
    }
    try png.write(to: url, options: .atomic)
}

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = cwd.appendingPathComponent("Resources", isDirectory: true)
try ensureDir(resources)

for spec in specs {
    let iconset = resources.appendingPathComponent("\(spec.name).iconset", isDirectory: true)
    try ensureDir(iconset)

    for s in sizes {
        // 1x
        let p1 = iconset.appendingPathComponent("icon_\(s)x\(s).png")
        try renderIconPNG(to: p1, size: s, spec: spec)
        // 2x for smaller sizes (up to 512@2x = 1024)
        if s <= 512 {
            let p2 = iconset.appendingPathComponent("icon_\(s)x\(s)@2x.png")
            try renderIconPNG(to: p2, size: s * 2, spec: spec)
        }
    }
}

print("✅ iconset generated in Resources/")

