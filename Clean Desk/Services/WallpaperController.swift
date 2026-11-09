#if !APPSTORE
import AppKit

/// Swaps every display's wallpaper for the user's chosen image while the desktop is hidden, remembering
/// what was there so it can be put back.
final class WallpaperController {
    private let preferences: Preferences
    private let workspace = NSWorkspace.shared

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    /// Sets the custom wallpaper on every connected display. Returns a message if something went wrong.
    @discardableResult
    func applyCustom() -> String? {
        guard let custom = preferences.customWallpaperURL else { return nil }
        guard FileManager.default.fileExists(atPath: custom.path) else {
            return "The custom wallpaper couldn't be found at \(custom.path)."
        }
        var originals = preferences.originalWallpapers
        var failure: String?
        for screen in NSScreen.screens {
            let key = screen.displayKey
            // Only remember the first thing we replace: applying again must not record our own image
            // as the "original". A missing entry with our image already showing means nothing to restore.
            if originals[key] == nil,
               let current = workspace.desktopImageURL(for: screen),
               current.standardizedFileURL != custom.standardizedFileURL {
                originals[key] = current.path
            }
            do {
                try workspace.setDesktopImageURL(custom, for: screen, options: Self.fillOptions)
            } catch {
                failure = "Couldn't set the wallpaper: \(error.localizedDescription)"
            }
        }
        preferences.originalWallpapers = originals
        return failure
    }

    /// Puts each connected display's previous wallpaper back. Entries for displays that aren't connected
    /// right now are kept for when they return.
    @discardableResult
    func restoreOriginals() -> String? {
        var originals = preferences.originalWallpapers
        guard !originals.isEmpty else { return nil }
        var failure: String?
        for screen in NSScreen.screens {
            let key = screen.displayKey
            guard let path = originals[key] else { continue }
            let options = workspace.desktopImageOptions(for: screen) ?? Self.fillOptions
            do {
                try workspace.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: options)
                originals[key] = nil
            } catch {
                failure = "Couldn't restore the wallpaper: \(error.localizedDescription)"
            }
        }
        preferences.originalWallpapers = originals
        return failure
    }

    private static let fillOptions: [NSWorkspace.DesktopImageOptionKey: Any] = [
        .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
        .allowClipping: true,
    ]
}

extension NSScreen {
    /// Stable per-display identifier (CGDirectDisplayID) for keying saved wallpapers.
    var displayKey: String {
        let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return String(number?.uint32Value ?? 0)
    }
}
#endif
