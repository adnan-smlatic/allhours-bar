// Renders the app icon: `swift scripts/make-icon.swift <output.png>` (1024×1024).
import AppKit

let side = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon_1024.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824pt rounded square centred on a 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.28).cgColor)
NSColor.black.setFill()
shape.fill()
ctx.restoreGState()

NSGradient(colors: [
    NSColor(srgbRed: 0.16, green: 0.78, blue: 0.62, alpha: 1),
    NSColor(srgbRed: 0.10, green: 0.42, blue: 0.80, alpha: 1),
])!.draw(in: shape, angle: -65)

// Soft highlight on the top half.
ctx.saveGState()
shape.addClip()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
    .draw(in: CGRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
ctx.restoreGState()

let config = NSImage.SymbolConfiguration(pointSize: 470, weight: .medium)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let size = symbol.size
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    symbol.draw(in: CGRect(x: (CGFloat(side) - size.width) / 2, y: (CGFloat(side) - size.height) / 2, width: size.width, height: size.height))
    ctx.restoreGState()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
