#!/usr/bin/swift

import AppKit

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: mask-app-icon.swift input.png output.png\n".utf8))
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let image = NSImage(contentsOf: inputURL),
      let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write(Data("Could not read source icon.\n".utf8))
    exit(1)
}

let width = source.width
let height = source.height
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
let inset = CGFloat(width) * 0.013
let bounds = NSRect(x: inset, y: inset, width: CGFloat(width) - inset * 2, height: CGFloat(height) - inset * 2)
NSBezierPath(roundedRect: bounds, xRadius: CGFloat(width) * 0.2, yRadius: CGFloat(height) * 0.2).addClip()
NSGraphicsContext.current?.cgContext.draw(source, in: NSRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: outputURL, options: .atomic)
