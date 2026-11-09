#if APPSTORE
import AppKit

/// App Store engine. The sandbox can't change Finder's settings or relaunch it, so instead the desktop
/// icons on every display are covered by a window that sits just above the icon layer and below every
/// other window, drawing the wallpaper (or the custom image). Nothing on disk is touched and the icons
/// are back the instant the cover comes down.
final class DesktopCover {
    private let preferences: Preferences
    private var windows: [CoverWindow] = []

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    var isCovering: Bool { !windows.isEmpty }

    func cover() {
        uncover()
        for screen in NSScreen.screens {
            let window = CoverWindow(screen: screen, image: image(for: screen))
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    func uncover() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    /// Rebuilds the cover after displays, Spaces or the wallpaper settings change.
    func refresh() {
        guard isCovering else { return }
        cover()
    }

    private func image(for screen: NSScreen) -> NSImage? {
        if preferences.useCustomWallpaper, let url = preferences.customWallpaperURL, let image = NSImage(contentsOf: url) {
            return image
        }
        // System wallpapers are readable from the sandbox; a picture of the user's own usually isn't,
        // and the window then falls back to a plain backdrop.
        if let url = NSWorkspace.shared.desktopImageURL(for: screen), let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
}

private final class CoverWindow: NSWindow {
    init(screen: NSScreen, image: NSImage?) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        // One above the desktop icons, below the backstop menu level and every ordinary window.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = true
        hasShadow = false
        backgroundColor = .black
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        contentView = CoverView(image: image)
        setFrame(screen.frame, display: true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Clicking the covered desktop does what clicking the real one does: Finder comes forward.
    override func mouseDown(with event: NSEvent) {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.finder" }?.activate()
    }
}

/// Draws the image scaled to fill, or a calm blue backdrop when there is no image to draw.
private final class CoverView: NSView {
    private let image: NSImage?

    init(image: NSImage?) {
        self.image = image
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            NSGradient(colors: [NSColor(srgbRed: 0.16, green: 0.33, blue: 0.70, alpha: 1), NSColor(srgbRed: 0.07, green: 0.14, blue: 0.38, alpha: 1)])?
                .draw(in: bounds, angle: -90)
            return
        }
        let scale = max(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        NSColor.black.setFill()
        bounds.fill()
        image.draw(in: NSRect(origin: origin, size: size), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }
}
#endif
