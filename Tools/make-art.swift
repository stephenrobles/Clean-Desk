// Composes the marketing images: the beardfm.app hero and the Mac App Store screenshots.
//
// Usage: swift Tools/make-art.swift hero  <settings-window.png> <out.jpg>     (1600 × 1000)
//        swift Tools/make-art.swift shot1 <settings-window.png> <out.png>     (2880 × 1800, settings)
//        swift Tools/make-art.swift shot2 <out.png>                           (2880 × 1800, before/after)
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func background(_ rect: NSRect) {
    NSGradient(colors: [color(0x58ACFF), color(0x2A7BEA), color(0x1D5AC2)], atLocations: [0, 0.6, 1], colorSpace: .sRGB)!.draw(in: rect, angle: -90)
}

func sparkle(center: NSPoint, radius: CGFloat, waist: CGFloat = 0.22) -> NSBezierPath {
    let path = NSBezierPath()
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4 - .pi / 2
        let r = i.isMultiple(of: 2) ? radius : radius * waist
        let point = NSPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        i == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close()
    return path
}

/// A translucent menu bar strip with the Clean Desk sparkle at the right, like the real one.
func menuBar(in rect: NSRect, scale: CGFloat) {
    color(0xFFFFFF, 0.22).setFill()
    rect.fill()
    let font = NSFont.systemFont(ofSize: 13 * scale, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    ("Finder" as NSString).draw(at: NSPoint(x: rect.minX + 18 * scale, y: rect.midY - 8 * scale), withAttributes: attrs)
    let clock = "Mon 9:41 AM" as NSString
    let clockSize = clock.size(withAttributes: attrs)
    clock.draw(at: NSPoint(x: rect.maxX - clockSize.width - 16 * scale, y: rect.midY - 8 * scale), withAttributes: attrs)
    NSColor.white.setFill()
    sparkle(center: NSPoint(x: rect.maxX - clockSize.width - 48 * scale, y: rect.midY), radius: 8.5 * scale).fill()
}

/// Screen captures carry a 144 dpi size in points; lay them out by their pixels.
func pixelSize(_ image: NSImage) -> NSSize {
    guard let rep = image.representations.first else { return image.size }
    return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
}

func drawWindow(_ image: NSImage, in frame: NSRect) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -frame.height * 0.02)
    shadow.shadowBlurRadius = frame.height * 0.04
    shadow.shadowColor = color(0x061437, 0.5)
    shadow.set()
    NSBezierPath(roundedRect: frame, xRadius: frame.width * 0.022, yRadius: frame.width * 0.022).fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGraphicsContext.current?.saveGraphicsState()
    NSBezierPath(roundedRect: frame, xRadius: frame.width * 0.022, yRadius: frame.width * 0.022).addClip()
    image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.current?.restoreGraphicsState()
}

func headline(_ title: String, _ subtitle: String, at origin: NSPoint, width: CGFloat, titleSize: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineHeightMultiple = 0.95
    let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: titleSize, weight: .bold), .foregroundColor: NSColor.white, .paragraphStyle: paragraph]
    let subAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: titleSize * 0.42, weight: .medium), .foregroundColor: color(0xFFFFFF, 0.85)]
    let lines = CGFloat(title.components(separatedBy: "\n").count)
    let titleRect = NSRect(x: origin.x, y: origin.y - titleSize * 1.2 * lines, width: width, height: titleSize * 1.2 * lines)
    (title as NSString).draw(in: titleRect, withAttributes: titleAttrs)
    (subtitle as NSString).draw(in: NSRect(x: origin.x, y: titleRect.minY - titleSize * 1.4, width: width, height: titleSize * 1.3), withAttributes: subAttrs)
}

/// A simplified desktop: wallpaper panel, optionally scattered with generic file icons.
func desktop(in rect: NSRect, cluttered: Bool, scale: CGFloat) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowOffset = NSSize(width: 0, height: -14 * scale); shadow.shadowBlurRadius = 36 * scale; shadow.shadowColor = color(0x061437, 0.5); shadow.set()
    color(0x0B1E4A).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 24 * scale, yRadius: 24 * scale).fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGraphicsContext.current?.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: 24 * scale, yRadius: 24 * scale).addClip()
    NSGradient(colors: [color(0x7FD3F7), color(0x4FA3E8), color(0x6F7BE6), color(0xF2A6C8)], atLocations: [0, 0.4, 0.75, 1], colorSpace: .sRGB)!.draw(in: rect, angle: -35)
    menuBar(in: NSRect(x: rect.minX, y: rect.maxY - 30 * scale, width: rect.width, height: 30 * scale), scale: scale)
    if cluttered {
        let symbols = ["folder.fill", "doc.fill", "photo.fill", "externaldrive.fill", "doc.zipper", "folder.fill", "doc.richtext.fill", "film.fill", "folder.fill", "doc.fill", "externaldrive.fill", "tablecells.fill"]
        let names = ["Projects", "Notes.txt", "IMG_4821", "Backup", "Archive.zip", "Downloads", "Invoice", "Clip.mov", "Old Stuff", "Draft 3", "Time Machine", "Budget"]
        let config = NSImage.SymbolConfiguration(pointSize: 40 * scale, weight: .regular)
        let columns = 4, cell = 104 * scale
        for (i, symbol) in symbols.enumerated() {
            let col = CGFloat(columns - 1 - i % columns), row = CGFloat(i / columns)
            let x = rect.maxX - 40 * scale - (col + 1) * cell + (CGFloat((i * 37) % 19) - 9) * scale
            let y = rect.maxY - 50 * scale - (row + 1) * cell + (CGFloat((i * 53) % 17) - 8) * scale
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let tinted = NSImage(size: image.size, flipped: false) { r in
                    image.draw(in: r); color(0xFFFFFF, 0.92).set(); r.fill(using: .sourceAtop); return true
                }
                tinted.draw(in: NSRect(x: x + (cell - image.size.width) / 2, y: y + 34 * scale, width: image.size.width, height: image.size.height))
            }
            let label = names[i] as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12 * scale, weight: .medium), .foregroundColor: NSColor.white]
            let size = label.size(withAttributes: attrs)
            color(0x000000, 0.28).setFill()
            NSBezierPath(roundedRect: NSRect(x: x + (cell - size.width) / 2 - 6 * scale, y: y + 12 * scale, width: size.width + 12 * scale, height: size.height + 4 * scale), xRadius: 5 * scale, yRadius: 5 * scale).fill()
            label.draw(at: NSPoint(x: x + (cell - size.width) / 2, y: y + 14 * scale), withAttributes: attrs)
        }
    } else {
        NSColor.white.setFill()
        sparkle(center: NSPoint(x: rect.midX + rect.width * 0.18, y: rect.midY + rect.height * 0.12), radius: 46 * scale).fill()
        sparkle(center: NSPoint(x: rect.midX + rect.width * 0.11, y: rect.midY + rect.height * 0.02), radius: 20 * scale).fill()
    }
    // Dock.
    let dock = NSRect(x: rect.midX - 200 * scale, y: rect.minY + 14 * scale, width: 400 * scale, height: 46 * scale)
    color(0xFFFFFF, 0.3).setFill()
    NSBezierPath(roundedRect: dock, xRadius: 14 * scale, yRadius: 14 * scale).fill()
    for i in 0..<8 {
        color([0x2D7CF6, 0xF35B5B, 0x34C759, 0xFF9F0A, 0xAF52DE, 0x5AC8FA, 0xFFD60A, 0x8E8E93][i]).setFill()
        NSBezierPath(roundedRect: NSRect(x: dock.minX + 12 * scale + CGFloat(i) * 48 * scale, y: dock.minY + 7 * scale, width: 32 * scale, height: 32 * scale), xRadius: 8 * scale, yRadius: 8 * scale).fill()
    }
    NSGraphicsContext.current?.restoreGraphicsState()
}

func render(size: NSSize, _ draw: (NSRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "hero":
    let window = NSImage(contentsOfFile: args[1])!
    let rep = render(size: NSSize(width: 1600, height: 1000)) { rect in
        background(rect)
        menuBar(in: NSRect(x: 0, y: rect.maxY - 36, width: rect.width, height: 36), scale: 1.25)
        let scale: CGFloat = 0.58
        let size = NSSize(width: pixelSize(window).width * scale, height: pixelSize(window).height * scale)
        drawWindow(window, in: NSRect(x: rect.maxX - size.width - 120, y: (rect.height - 36 - size.height) / 2, width: size.width, height: size.height))
        headline("Hide everything\non your desktop.", "One click, or one keyboard shortcut.", at: NSPoint(x: 110, y: 700), width: 760, titleSize: 76)
        let icon = NSImage(contentsOfFile: "Clean Desk/Assets.xcassets/AppIcon.appiconset/icon_512.png")!
        icon.draw(in: NSRect(x: 100, y: 120, width: 300, height: 300))
    }
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: URL(fileURLWithPath: args[2]))
case "shot1":
    let window = NSImage(contentsOfFile: args[1])!
    let rep = render(size: NSSize(width: 2880, height: 1800)) { rect in
        background(rect)
        headline("Hide everything\non your desktop.", "Files, folders and disks disappear with one click or ⌃⌥⌘D.", at: NSPoint(x: 180, y: 1280), width: 1300, titleSize: 128)
        let icon = NSImage(contentsOfFile: "Clean Desk/Assets.xcassets/AppIcon.appiconset/icon_1024.png")!
        icon.draw(in: NSRect(x: 170, y: 170, width: 520, height: 520))
        let size = pixelSize(window)
        let fit = min(1.15, 1520 / size.height)
        let scaled = NSSize(width: size.width * fit, height: size.height * fit)
        drawWindow(window, in: NSRect(x: rect.maxX - scaled.width - 200, y: (rect.height - scaled.height) / 2, width: scaled.width, height: scaled.height))
    }
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
case "shot2":
    let rep = render(size: NSSize(width: 2880, height: 1800)) { rect in
        background(rect)
        headline("A clean desktop, instantly.", "Nothing is moved or deleted. Show it all again whenever you like.", at: NSPoint(x: 180, y: 1660), width: 2600, titleSize: 112)
        let w: CGFloat = 1200, h: CGFloat = 750
        desktop(in: NSRect(x: 180, y: 380, width: w, height: h), cluttered: true, scale: 1.6)
        desktop(in: NSRect(x: rect.maxX - 180 - w, y: 380, width: w, height: h), cluttered: false, scale: 1.6)
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 44, weight: .semibold), .foregroundColor: color(0xFFFFFF, 0.9)]
        ("Before" as NSString).draw(at: NSPoint(x: 180, y: 290), withAttributes: attrs)
        ("After" as NSString).draw(at: NSPoint(x: rect.maxX - 180 - w, y: 290), withAttributes: attrs)
        NSColor.white.setFill()
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: rect.midX - 60, y: 755)); arrow.line(to: NSPoint(x: rect.midX + 50, y: 755))
        arrow.move(to: NSPoint(x: rect.midX + 10, y: 795)); arrow.line(to: NSPoint(x: rect.midX + 50, y: 755)); arrow.line(to: NSPoint(x: rect.midX + 10, y: 715))
        arrow.lineWidth = 14; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
        NSColor.white.setStroke(); arrow.stroke()
    }
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
default:
    print("usage: make-art.swift hero|shot1|shot2 …"); exit(1)
}
print("wrote \(args.last!)")
