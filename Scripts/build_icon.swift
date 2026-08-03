import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(Data("Usage: swift build_icon.swift OUTPUT.png\n".utf8))
  exit(64)
}

guard
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ),
  let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
else {
  FileHandle.standardError.write(Data("Unable to create drawing context\n".utf8))
  exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
let context = graphicsContext.cgContext
context.setAllowsAntialiasing(true)
let backgroundRect = NSRect(x: 24, y: 24, width: 976, height: 976)
let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 224, yRadius: 224)
let backgroundGradient = NSGradient(
  starting: NSColor(red: 0.04, green: 0.08, blue: 0.15, alpha: 1),
  ending: NSColor(red: 0.08, green: 0.18, blue: 0.29, alpha: 1)
)
backgroundGradient?.draw(in: backgroundPath, angle: -55)

func drawCard(rect: NSRect, color: NSColor, alpha: CGFloat) {
  let path = NSBezierPath(roundedRect: rect, xRadius: 72, yRadius: 72)
  color.withAlphaComponent(alpha).setFill()
  path.fill()
  color.withAlphaComponent(0.92).setStroke()
  path.lineWidth = 18
  path.stroke()
}

drawCard(
  rect: NSRect(x: 246, y: 334, width: 498, height: 390),
  color: NSColor(red: 0.20, green: 0.78, blue: 0.93, alpha: 1),
  alpha: 0.18
)
drawCard(
  rect: NSRect(x: 320, y: 250, width: 498, height: 390),
  color: NSColor(red: 0.32, green: 0.91, blue: 0.70, alpha: 1),
  alpha: 0.19
)

let portraitColor = NSColor(red: 0.85, green: 0.98, blue: 0.94, alpha: 1)
portraitColor.setFill()
NSBezierPath(ovalIn: NSRect(x: 489, y: 472, width: 150, height: 150)).fill()
NSBezierPath(
  roundedRect: NSRect(x: 428, y: 326, width: 272, height: 126),
  xRadius: 63,
  yRadius: 63
).fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
  FileHandle.standardError.write(Data("Unable to encode icon\n".utf8))
  exit(1)
}

do {
  try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
} catch {
  FileHandle.standardError.write(Data("Unable to write icon: \(error.localizedDescription)\n".utf8))
  exit(1)
}
