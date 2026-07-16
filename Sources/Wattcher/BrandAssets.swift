import AppKit

@MainActor
enum BrandAssets {
    static var applicationIcon: NSImage {
        if let path = Bundle.main.path(forResource: "Wattcher", ofType: "icns"),
           let image = NSImage(contentsOfFile: path) {
            return image
        }
        return NSApplication.shared.applicationIconImage
    }

    static var statusIcon: NSImage {
        let image = NSImage(size: NSSize(width: 19, height: 19), flipped: false) { rect in
            NSColor.black.setFill()
            drawRay(in: rect, angle: 0)
            drawRay(in: rect, angle: -52)
            drawRay(in: rect, angle: 52)
            drawPulse(in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Wattcher"
        return image
    }

    private static func drawRay(in rect: NSRect, angle: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -rect.midX, yBy: -rect.midY)
        transform.concat()
        let ray = NSBezierPath(
            roundedRect: NSRect(x: rect.midX - 1.5, y: 10.2, width: 3, height: 6.5),
            xRadius: 1.5,
            yRadius: 1.5
        )
        ray.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawPulse(in rect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 3, y: 3.2))
        path.line(to: NSPoint(x: 6.7, y: 8.1))
        path.line(to: NSPoint(x: 8.1, y: 6.2))
        path.line(to: NSPoint(x: 9.5, y: 9.5))
        path.line(to: NSPoint(x: 10.9, y: 6.4))
        path.line(to: NSPoint(x: 12.3, y: 8.1))
        path.line(to: NSPoint(x: 16, y: 3.2))
        path.line(to: NSPoint(x: 13.6, y: 2))
        path.line(to: NSPoint(x: 10.9, y: 5.5))
        path.line(to: NSPoint(x: 9.5, y: 2.8))
        path.line(to: NSPoint(x: 8.1, y: 5.5))
        path.line(to: NSPoint(x: 5.4, y: 2))
        path.close()
        path.fill()
    }
}
