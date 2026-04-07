import AppKit
import Foundation

struct IconRenderer {
    let outputRoot: URL

    private let sizes: [(name: String, pixels: Int)] = [
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

    func render() throws {
        let iconsetURL = outputRoot.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        let icnsURL = outputRoot.appendingPathComponent("AppIcon.icns")

        try? FileManager.default.removeItem(at: iconsetURL)
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        for size in sizes {
            let image = NSImage(size: NSSize(width: size.pixels, height: size.pixels))
            image.lockFocus()
            drawIcon(in: NSRect(x: 0, y: 0, width: size.pixels, height: size.pixels))
            image.unlockFocus()

            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "OpenWithGUI.IconRenderer", code: 1)
            }

            try pngData.write(to: iconsetURL.appendingPathComponent(size.name))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "OpenWithGUI.IconRenderer", code: 2)
        }
    }

    private func drawIcon(in rect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high
        let size = min(rect.width, rect.height)

        let outerInset = size * 0.06
        let outerRect = rect.insetBy(dx: outerInset, dy: outerInset)
        let outerRadius = size * 0.22

        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.18)
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
        shadow.shadowBlurRadius = size * 0.04
        shadow.set()

        let basePath = NSBezierPath(roundedRect: outerRect, xRadius: outerRadius, yRadius: outerRadius)
        let baseGradient = NSGradient(
            starting: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.985, alpha: 1.0),
            ending: NSColor(calibratedRed: 0.87, green: 0.90, blue: 0.95, alpha: 1.0)
        )!
        baseGradient.draw(in: basePath, angle: -90)

        NSGraphicsContext.saveGraphicsState()
        basePath.addClip()
        let highlightRect = NSRect(
            x: outerRect.minX,
            y: outerRect.midY,
            width: outerRect.width,
            height: outerRect.height * 0.55
        )
        let highlightPath = NSBezierPath(rect: highlightRect)
        NSColor(calibratedWhite: 1, alpha: 0.24).setFill()
        highlightPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedWhite: 1, alpha: 0.48).setStroke()
        basePath.lineWidth = max(1, size * 0.012)
        basePath.stroke()

        let documentWidth = size * 0.46
        let documentHeight = size * 0.56
        let documentRect = NSRect(
            x: rect.midX - documentWidth * 0.68,
            y: rect.midY - documentHeight * 0.34,
            width: documentWidth,
            height: documentHeight
        )
        let fold = size * 0.10

        let documentPath = NSBezierPath()
        documentPath.move(to: NSPoint(x: documentRect.minX, y: documentRect.minY))
        documentPath.line(to: NSPoint(x: documentRect.minX, y: documentRect.maxY))
        documentPath.line(to: NSPoint(x: documentRect.maxX - fold, y: documentRect.maxY))
        documentPath.line(to: NSPoint(x: documentRect.maxX, y: documentRect.maxY - fold))
        documentPath.line(to: NSPoint(x: documentRect.maxX, y: documentRect.minY))
        documentPath.close()

        let documentGradient = NSGradient(
            starting: NSColor(calibratedWhite: 1.0, alpha: 1.0),
            ending: NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.98, alpha: 1.0)
        )!
        documentGradient.draw(in: documentPath, angle: -90)

        NSColor(calibratedRed: 0.76, green: 0.81, blue: 0.89, alpha: 1.0).setStroke()
        documentPath.lineWidth = max(1, size * 0.01)
        documentPath.stroke()

        let foldPath = NSBezierPath()
        foldPath.move(to: NSPoint(x: documentRect.maxX - fold, y: documentRect.maxY))
        foldPath.line(to: NSPoint(x: documentRect.maxX - fold, y: documentRect.maxY - fold))
        foldPath.line(to: NSPoint(x: documentRect.maxX, y: documentRect.maxY - fold))
        foldPath.close()
        NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.96, alpha: 1.0).setFill()
        foldPath.fill()

        let lineColor = NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.90, alpha: 1.0)
        for index in 0..<3 {
            let y = documentRect.maxY - documentHeight * (0.26 + CGFloat(index) * 0.18)
            let line = NSBezierPath(roundedRect: NSRect(
                x: documentRect.minX + documentWidth * 0.14,
                y: y,
                width: documentWidth * 0.48,
                height: max(2, size * 0.022)
            ), xRadius: size * 0.012, yRadius: size * 0.012)
            lineColor.withAlphaComponent(index == 2 ? 0.45 : 0.7).setFill()
            line.fill()
        }

        let badgeSize = size * 0.34
        let badgeRect = NSRect(
            x: rect.midX + size * 0.02,
            y: rect.midY - badgeSize * 0.28,
            width: badgeSize,
            height: badgeSize
        )
        let badgePath = NSBezierPath(ovalIn: badgeRect)
        let badgeGradient = NSGradient(
            starting: NSColor(calibratedRed: 0.33, green: 0.63, blue: 0.98, alpha: 1.0),
            ending: NSColor(calibratedRed: 0.11, green: 0.44, blue: 0.93, alpha: 1.0)
        )!
        badgeGradient.draw(in: badgePath, angle: -90)

        NSColor(calibratedWhite: 1, alpha: 0.35).setStroke()
        badgePath.lineWidth = max(1, size * 0.01)
        badgePath.stroke()

        drawArrows(in: badgeRect, size: size)
    }

    private func drawArrows(in rect: NSRect, size: CGFloat) {
        let strokeWidth = max(1.5, size * 0.032)
        let inset = rect.width * 0.24
        let topY = rect.midY + rect.height * 0.12
        let bottomY = rect.midY - rect.height * 0.12
        let leftX = rect.minX + inset
        let rightX = rect.maxX - inset

        let arrowColor = NSColor(calibratedWhite: 1.0, alpha: 0.98)
        arrowColor.setStroke()
        arrowColor.setFill()

        let topLine = NSBezierPath()
        topLine.lineCapStyle = .round
        topLine.lineJoinStyle = .round
        topLine.lineWidth = strokeWidth
        topLine.move(to: NSPoint(x: leftX, y: topY))
        topLine.line(to: NSPoint(x: rightX - strokeWidth * 0.6, y: topY))
        topLine.stroke()

        let topHead = NSBezierPath()
        topHead.move(to: NSPoint(x: rightX, y: topY))
        topHead.line(to: NSPoint(x: rightX - strokeWidth * 1.3, y: topY + strokeWidth * 0.95))
        topHead.line(to: NSPoint(x: rightX - strokeWidth * 1.3, y: topY - strokeWidth * 0.95))
        topHead.close()
        topHead.fill()

        let bottomLine = NSBezierPath()
        bottomLine.lineCapStyle = .round
        bottomLine.lineJoinStyle = .round
        bottomLine.lineWidth = strokeWidth
        bottomLine.move(to: NSPoint(x: rightX, y: bottomY))
        bottomLine.line(to: NSPoint(x: leftX + strokeWidth * 0.6, y: bottomY))
        bottomLine.stroke()

        let bottomHead = NSBezierPath()
        bottomHead.move(to: NSPoint(x: leftX, y: bottomY))
        bottomHead.line(to: NSPoint(x: leftX + strokeWidth * 1.3, y: bottomY + strokeWidth * 0.95))
        bottomHead.line(to: NSPoint(x: leftX + strokeWidth * 1.3, y: bottomY - strokeWidth * 0.95))
        bottomHead.close()
        bottomHead.fill()
    }
}

let outputRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Assets", isDirectory: true)
try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
try IconRenderer(outputRoot: outputRoot).render()
print("Generated app icon at \(outputRoot.path)/AppIcon.icns")
