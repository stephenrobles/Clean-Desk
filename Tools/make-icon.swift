// Renders the Clean Desk app icon: a tidy, empty desk on a blue tile.
//
// Usage: swift Tools/make-icon.swift <output-dir> [variant]
//   variant 1  simple desk with sparkles
//   variant 2  flat desk with a lamp (default)
//   variant 3  pedestal desk with drawers
// Writes icon_<size>.png for 16…1024 into <output-dir>.
import AppKit

let canvas: CGFloat = 1024
let args = Array(CommandLine.arguments.dropFirst())
let output = URL(fileURLWithPath: args.first ?? ".")
let variant = args.count > 1 ? Int(args[1]) ?? 2 : 2

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// macOS-style continuous-corner tile (superellipse) inside the standard 824pt icon grid.
func squircle(in rect: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    for i in 0...720 {
        let t = CGFloat(i) / 720 * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = rect.midX + a * copysign(pow(abs(c), 2 / n), c)
        let y = rect.midY + b * copysign(pow(abs(s), 2 / n), s)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

extension CGRect { var path: CGPath { CGPath(rect: self, transform: nil) } }

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Four-point sparkle centred on `center`.
func sparklePath(center: CGPoint, radius: CGFloat, waist: CGFloat = 0.22) -> CGPath {
    let path = CGMutablePath()
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4 - .pi / 2
        let r = i.isMultiple(of: 2) ? radius : radius * waist
        let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        i == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

func fill(_ path: CGPath, in context: CGContext, gradient colors: [CGColor], locations: [CGFloat], from start: CGPoint, to end: CGPoint) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
    context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
}

func fill(_ path: CGPath, in context: CGContext, color: CGColor, shadow: (CGSize, CGFloat, CGColor)? = nil) {
    context.saveGState()
    if let (offset, blur, shadowColor) = shadow { context.setShadow(offset: offset, blur: blur, color: shadowColor) }
    context.addPath(path)
    context.setFillColor(color)
    context.fillPath()
    context.restoreGState()
}

func sparkles(_ items: [(CGPoint, CGFloat)], in context: CGContext) {
    for (center, radius) in items {
        fill(sparklePath(center: center, radius: radius), in: context, color: color(0xFFFFFF),
             shadow: (.zero, 18, color(0xFFFFFF, 0.8)))
    }
}

/// A desk top slab with a slightly darker front edge, in warm cream so it reads against the blue.
func deskTop(_ rect: CGRect, in context: CGContext) {
    let slab = rounded(rect, 18)
    fill(slab, in: context, color: color(0xF4ECDF), shadow: (CGSize(width: 0, height: -10), 26, color(0x061437, 0.45)))
    fill(slab, in: context, gradient: [color(0xFBF6EC), color(0xE9DCC6)], locations: [0, 1],
         from: CGPoint(x: rect.midX, y: rect.maxY), to: CGPoint(x: rect.midX, y: rect.minY))
    // Thin highlight along the top edge.
    let edge = CGRect(x: rect.minX + 14, y: rect.maxY - 8, width: rect.width - 28, height: 5)
    fill(rounded(edge, 2.5), in: context, color: color(0xFFFFFF, 0.7))
}

func leg(_ rect: CGRect, in context: CGContext) {
    fill(rounded(rect, 12), in: context, gradient: [color(0xE2D5BF), color(0xC8B99F)], locations: [0, 1],
         from: CGPoint(x: rect.midX, y: rect.maxY), to: CGPoint(x: rect.midX, y: rect.minY))
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    context.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    context.setShouldAntialias(true)

    let tile = squircle(in: CGRect(x: 100, y: 100, width: 824, height: 824))
    fill(tile, in: context, color: color(0x0F2A5C), shadow: (CGSize(width: 0, height: -10), 24, color(0x000000, 0.35)))

    switch variant {
    case 2:
        // Flat lamp desk: azure tile, flat cream furniture, generous side padding.
        fill(tile, in: context, gradient: [color(0x58ACFF), color(0x2A7BEA), color(0x1D5AC2)], locations: [0, 0.6, 1],
             from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
        context.saveGState(); context.addPath(tile); context.clip()
        fill(CGPath(ellipseIn: CGRect(x: 302, y: 262, width: 420, height: 44), transform: nil), in: context, color: color(0x0B2A6E, 0.25))
        context.restoreGState()
        let cream = color(0xF4ECDF), creamDark = color(0xDDCFB6)
        // Legs.
        fill(rounded(CGRect(x: 306, y: 300, width: 40, height: 180), 10), in: context, color: creamDark)
        fill(rounded(CGRect(x: 678, y: 300, width: 40, height: 180), 10), in: context, color: creamDark)
        // Light cone, behind the desk top.
        let cone = CGMutablePath()
        cone.move(to: CGPoint(x: 606, y: 652)); cone.addLine(to: CGPoint(x: 724, y: 652))
        cone.addLine(to: CGPoint(x: 580, y: 524)); cone.addLine(to: CGPoint(x: 350, y: 524)); cone.closeSubpath()
        fill(cone, in: context, color: color(0xFFF3C4, 0.28))
        // Desk top: flat slab with a slightly darker front edge.
        let deskRect = CGRect(x: 262, y: 470, width: 500, height: 56)
        fill(rounded(deskRect, 14), in: context, color: cream)
        fill(rounded(CGRect(x: 262, y: 470, width: 500, height: 22), 11), in: context, color: creamDark)
        fill(CGRect(x: 262, y: 481, width: 500, height: 14).path, in: context, color: creamDark)
        // Lamp: base, stem, shade.
        fill(rounded(CGRect(x: 612, y: 524, width: 104, height: 20), 10), in: context, color: cream)
        fill(rounded(CGRect(x: 656, y: 540, width: 16, height: 140), 8), in: context, color: cream)
        let shade = CGMutablePath()
        shade.move(to: CGPoint(x: 604, y: 650)); shade.addLine(to: CGPoint(x: 726, y: 650))
        shade.addLine(to: CGPoint(x: 700, y: 722)); shade.addLine(to: CGPoint(x: 630, y: 722)); shade.closeSubpath()
        fill(shade.union(shade.copy(strokingWithWidth: 20, lineCap: .round, lineJoin: .round, miterLimit: 10)), in: context, color: cream)
        // Sparkles, flat.
        fill(sparklePath(center: CGPoint(x: 384, y: 688), radius: 54), in: context, color: color(0xFFFFFF))
        fill(sparklePath(center: CGPoint(x: 466, y: 618), radius: 24), in: context, color: color(0xFFFFFF))
    case 3:
        // Indigo tile.
        fill(tile, in: context, gradient: [color(0x6B7CFF), color(0x3A4CE0), color(0x1F2C96)], locations: [0, 0.55, 1],
             from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
        context.saveGState(); context.addPath(tile); context.clip()
        fill(CGPath(ellipseIn: CGRect(x: 212, y: 236, width: 600, height: 74), transform: nil), in: context, color: color(0x0E1A66, 0.4))
        context.restoreGState()
        // Left leg and a drawer pedestal on the right.
        leg(CGRect(x: 226, y: 280, width: 46, height: 260), in: context)
        let pedestal = CGRect(x: 612, y: 280, width: 190, height: 260)
        fill(rounded(pedestal, 16), in: context, gradient: [color(0xEFE5D4), color(0xD7C9B0)], locations: [0, 1],
             from: CGPoint(x: pedestal.midX, y: pedestal.maxY), to: CGPoint(x: pedestal.midX, y: pedestal.minY))
        for i in 0..<3 {
            let y = pedestal.minY + 18 + CGFloat(i) * 78
            fill(rounded(CGRect(x: pedestal.minX + 16, y: y, width: pedestal.width - 32, height: 64), 10), in: context, color: color(0xFBF6EC))
            fill(rounded(CGRect(x: pedestal.midX - 26, y: y + 27, width: 52, height: 10), 5), in: context, color: color(0xB9A98C))
        }
        deskTop(CGRect(x: 180, y: 540, width: 664, height: 64), in: context)
        sparkles([(CGPoint(x: 400, y: 730), 78), (CGPoint(x: 520, y: 672), 34)], in: context)
    default:
        // Deep blue tile.
        fill(tile, in: context, gradient: [color(0x3F84FF), color(0x1F55D9), color(0x153A94)], locations: [0, 0.55, 1],
             from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
        context.saveGState(); context.addPath(tile); context.clip()
        fill(CGPath(ellipseIn: CGRect(x: 232, y: 250, width: 560, height: 70), transform: nil), in: context, color: color(0x0A2470, 0.4))
        context.restoreGState()
        leg(CGRect(x: 250, y: 290, width: 44, height: 230), in: context)
        leg(CGRect(x: 730, y: 290, width: 44, height: 230), in: context)
        // A cross-brace so the legs read as a desk, not a table top floating on sticks.
        fill(rounded(CGRect(x: 294, y: 380, width: 436, height: 22), 11), in: context, color: color(0xD2C4AA))
        deskTop(CGRect(x: 212, y: 520, width: 600, height: 60), in: context)
        sparkles([(CGPoint(x: 512, y: 720), 86), (CGPoint(x: 640, y: 650), 36), (CGPoint(x: 392, y: 646), 26)], in: context)
    }

    // Subtle inner rim on the tile.
    context.saveGState()
    context.addPath(tile)
    context.setStrokeColor(color(0xFFFFFF, 0.12))
    context.setLineWidth(3)
    context.strokePath()
    context.restoreGState()

    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    try render(size: size).write(to: output.appending(path: "icon_\(size).png"))
}
print("Wrote variant \(variant) icons to \(output.path)")
