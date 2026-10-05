// Renders the DMG window background.
// Usage: swift scripts/dmg/background.swift <out-dir>  →  background.png (600×400) and background@2x.png
//
// Finder draws icon labels black in Light Mode and white in Dark Mode, whatever the background,
// so the backdrop is a mid-tone slate where both stay readable.
import AppKit

let size = CGSize(width: 600, height: 400)
let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")

// Icon centres in Finder coordinates (origin top-left); keep in sync with settings.py.
let appCenter = CGPoint(x: 160, y: 200)
let applicationsCenter = CGPoint(x: 440, y: 200)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    // Work in top-left coordinates like Finder.
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)
    let flipped = NSGraphicsContext(cgContext: cg, flipped: true)
    NSGraphicsContext.current = flipped

    let bounds = CGRect(origin: .zero, size: size)

    // Base: slate gradient.
    NSGradient(colors: [color(0x6D7E94), color(0x58687E)])!.draw(in: bounds, angle: 90)

    // Brand glows (teal top-left, blue bottom-right).
    for (center, hex, radius) in [(CGPoint(x: 90, y: 40), 0x2BC79E, 320.0), (CGPoint(x: 560, y: 390), 0x1A6BCC, 360.0)] {
        NSGradient(colors: [color(UInt32(hex), 0.42), color(UInt32(hex), 0)])!
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
    }

    // Fine dot grid for texture.
    color(0xFFFFFF, 0.06).setFill()
    for x in stride(from: 12.0, to: size.width, by: 24) {
        for y in stride(from: 12.0, to: size.height, by: 24) {
            NSBezierPath(ovalIn: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)).fill()
        }
    }

    // Soft wells behind the two icon spots.
    for center in [appCenter, applicationsCenter] {
        let well = NSBezierPath(roundedRect: CGRect(x: center.x - 82, y: center.y - 78, width: 164, height: 176), xRadius: 28, yRadius: 28)
        color(0xFFFFFF, 0.07).setFill()
        well.fill()
        color(0xFFFFFF, 0.14).setStroke()
        well.lineWidth = 1
        well.stroke()
    }

    // Title and subtitle.
    func draw(_ text: String, font: NSFont, color textColor: NSColor, centerX: CGFloat, y: CGFloat, kern: CGFloat = 0) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .kern: kern]
        let string = NSAttributedString(string: text, attributes: attributes)
        let width = string.size().width
        string.draw(at: CGPoint(x: centerX - width / 2, y: y))
    }
    let rounded = NSFont.systemFont(ofSize: 24, weight: .bold).fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 24) }
    draw("All Hours Bar", font: rounded ?? .boldSystemFont(ofSize: 24), color: .white, centerX: size.width / 2, y: 30, kern: -0.3)
    draw("Drag the app into Applications to install", font: .systemFont(ofSize: 13, weight: .medium),
         color: color(0xFFFFFF, 0.72), centerX: size.width / 2, y: 64)

    // Arrow between the icons.
    let arrowY = appCenter.y - 6
    let start = CGPoint(x: appCenter.x + 92, y: arrowY)
    let end = CGPoint(x: applicationsCenter.x - 96, y: arrowY)
    let shaft = NSBezierPath()
    shaft.move(to: start)
    shaft.curve(to: end, controlPoint1: CGPoint(x: start.x + 40, y: arrowY - 26), controlPoint2: CGPoint(x: end.x - 40, y: arrowY - 26))
    shaft.lineWidth = 3
    shaft.lineCapStyle = .round
    shaft.setLineDash([0.5, 8], count: 2, phase: 0)
    color(0x7CF0CF).setStroke()
    shaft.stroke()

    let head = NSBezierPath()
    head.move(to: CGPoint(x: end.x - 12, y: arrowY - 10))
    head.line(to: CGPoint(x: end.x + 2, y: arrowY + 1))
    head.line(to: CGPoint(x: end.x - 13, y: arrowY + 7))
    head.lineWidth = 3.5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // Footer help.
    draw("Blocked on first open?  System Settings › Privacy & Security › Open Anyway",
         font: .systemFont(ofSize: 11, weight: .regular), color: color(0xFFFFFF, 0.55), centerX: size.width / 2, y: 352)
    draw("Unofficial · not affiliated with All Hours or Spica", font: .systemFont(ofSize: 10, weight: .regular),
         color: color(0xFFFFFF, 0.38), centerX: size.width / 2, y: 370)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try render(scale: 1).write(to: outDir.appendingPathComponent("background.png"))
try render(scale: 2).write(to: outDir.appendingPathComponent("background@2x.png"))
print("wrote \(outDir.path)/background.png and background@2x.png")
