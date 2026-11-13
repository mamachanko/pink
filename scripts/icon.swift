import AppKit

let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { fatalError("Icon context creation failed") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(srgbRed: 1, green: 0.92, blue: 0.95, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels)),
            xRadius: CGFloat(pixels) * 0.22, yRadius: CGFloat(pixels) * 0.22
        ).fill()
        let text = "💕" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CGFloat(pixels) * 0.68, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: (CGFloat(pixels) - textSize.width) / 2, y: (CGFloat(pixels) - textSize.height) / 2),
            withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(
            to: URL(fileURLWithPath: "\(directory)/icon_\(size)x\(size)\(suffix).png"))
    }
}
